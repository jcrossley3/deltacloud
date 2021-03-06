require 'rubygems'
require 'deltacloud'
require 'json'
require 'sinatra'
require 'sinatra/respond_to'
require 'erb'
require 'haml'
require 'open3'
require 'builder'
require 'drivers'
require 'sinatra/static_assets'
require 'sinatra/rabbit'
require 'sinatra/lazy_auth'
require 'deltacloud/validation'
require 'deltacloud/helpers'

configure do
  set :raise_errors => false
end

configure :development do
  # So we can just use puts for logging
  $stdout.sync = true
  $stderr.sync = true
end

DRIVER=ENV['API_DRIVER'] ? ENV['API_DRIVER'].to_sym : :mock

# You could use $API_HOST environment variable to change your hostname to
# whatever you want (eg. if you running API behind NAT)
HOSTNAME=ENV['API_HOST'] ? ENV['API_HOST'] : nil

Rack::Mime::MIME_TYPES.merge!({ ".gv" => "text/plain" })

Sinatra::Application.register Sinatra::RespondTo

# Common actions
#

def filter_all(model)
    filter = {}
    filter.merge!(:id => params[:id]) if params[:id]
    filter.merge!(:architecture => params[:architecture]) if params[:architecture]
    filter.merge!(:owner_id => params[:owner_id]) if params[:owner_id]
    filter.merge!(:state => params[:state]) if params[:state]
    filter = nil if filter.keys.size.eql?(0)
    singular = model.to_s.singularize.to_sym
    @elements = driver.send(model.to_sym, credentials, filter)
    instance_variable_set(:"@#{model}", @elements)
    respond_to do |format|
      format.html { haml :"#{model}/index" }
      format.xml { haml :"#{model}/index" }
      format.json { convert_to_json(singular, @elements) }
    end
end

def show(model)
  @element = driver.send(model, credentials, { :id => params[:id]} )
  instance_variable_set("@#{model}", @element)
  respond_to do |format|
    format.html { haml :"#{model.to_s.pluralize}/show" }
    format.xml { haml :"#{model.to_s.pluralize}/show" }
    format.json { convert_to_json(model, @element) }
  end
end


#
# Error handlers
#
def report_error(status, template)
  @error = request.env['sinatra.error']
  response.status = status
  respond_to do |format|
    format.xml { haml :"errors/#{template}", :layout => false }
    format.html { haml :"errors/#{template}" }
  end
end

error Deltacloud::Validation::Failure do
  report_error(400, "validation_failure")
end

error Deltacloud::AuthException do
  report_error(403, "auth_exception")
end

error Deltacloud::BackendError do
  report_error(500, "backend_error")
end

# Redirect to /api
get '/' do redirect '/api'; end

get '/api\/?' do
    @version = 1.0
    respond_to do |format|
        format.xml { haml :"api/show" }
        format.json do
          { :api => {
            :version => @version,
            :driver => DRIVER,
            :links => entry_points.collect { |l| { :rel => l[0], :href => l[1]} }
            }
          }.to_json
        end
        format.html { haml :"api/show" }
    end
end

# Rabbit DSL

collection :realms do
  description "Within a cloud provider a realm represents a boundary containing resources. The exact definition of a realm is left to the cloud provider. In some cases, a realm may represent different datacenters, different continents, or different pools of resources within a single datacenter. A cloud provider may insist that resources must all exist within a single realm in order to cooperate. For instance, storage volumes may only be allowed to be mounted to instances within the same realm."

  operation :index do
    description 'Operation will list all available realms. For specific architecture use "architecture" parameter.'
    param :id,            :string
    param :architecture,  :string,  :optional,  [ 'i386', 'x86_64' ]
    control { filter_all(:realms) }
  end

  #FIXME: It always shows whole list
  operation :show do
    description 'Show an realm identified by "id" parameter.'
    param :id,           :string, :required
    control { show(:realm) }
  end

end

collection :images do
  description "An image is a platonic form of a machine. Images are not directly executable, but are a template for creating actual instances of machines."

  operation :index do
    description 'The instances collection will return a set of all images available to the current use. You can filter images using "owner_id" and "architecture" parameter'
    param :id,            :string
    param :owner_id,      :string
    param :architecture,  :string,  :optional
    control { filter_all(:images) }
  end

  operation :show do
    description 'Show an image identified by "id" parameter.'
    param :id,           :string, :required
    control { show(:image) }
  end

end

collection :instance_states do
  description "The possible states of an instance, and how to traverse between them "

  operation :index do
    control do
      @machine = driver.instance_state_machine
      respond_to do |format|
        format.xml { haml :'instance_states/show', :layout => false }
        format.json do
          out = []
          @machine.states.each do |state|
            transitions = state.transitions.collect do |t|
              t.automatically? ? {:to => t.destination, :auto => 'true'} : {:to => t.destination, :action => t.action}
            end
            out << { :name => state, :transitions => transitions }
          end
          out.to_json
        end
        format.html { haml :'instance_states/show'}
        format.gv { erb :"instance_states/show" }
        format.png do
          # Trick respond_to into looking up the right template for the
          # graphviz file
          format(:gv); gv = erb :"instance_states/show"; format(:png)
          png =  ''
          cmd = 'dot -Kdot -Gpad="0.2,0.2" -Gsize="5.0,8.0" -Gdpi="180" -Tpng'
          Open3.popen3( cmd ) do |stdin, stdout, stderr|
            stdin.write( gv )
            stdin.close()
            png = stdout.read
          end
          png
        end
      end
    end
  end
end

get "/api/instances/new" do
  @instance = Instance.new( { :id=>params[:id], :image_id=>params[:image_id] } )
  @image   = driver.image( credentials, :id => params[:image_id] )
  @hardware_profiles = driver.hardware_profiles(credentials, :architecture => @image.architecture )
  @realms = driver.realms(credentials)
  respond_to do |format|
    format.html { haml :"instances/new" }
  end
end

def instance_action(name)
  @instance = driver.send(:"#{name}_instance", credentials, params["id"])

  return redirect(instances_url) if name.eql?(:destroy) or @instance.class!=Instance

  respond_to do |format|
    format.html { haml :"instances/show" }
    format.xml { haml :"instances/show" }
    format.json {convert_to_json(:instance, @instance) }
  end
end

collection :instances do
  description "An instance is a concrete machine realized from an image. The images collection may be obtained by following the link from the primary entry-point."

  operation :index do
    description "List all instances"
    param :id,            :string,  :optional
    param :state,         :string,  :optional
    control { filter_all(:instances) }
  end

  operation :show do
    description 'Show an image identified by "id" parameter.'
    param :id,           :string, :required
    control { show(:instance) }
  end

  operation :create do
    description "Create a new instance"
    param :image_id,     :string, :required
    param :realm_id,     :string, :optional
    param :hwp_id,       :string, :optional
    control do
      @image = driver.image(credentials, :id => params[:image_id])
      instance = driver.create_instance(credentials, @image.id, params)
      respond_to do |format|
        format.xml do
          response.status = 201  # Created
          response['Location'] = instance_url(instance.id)
          @instance = instance
          haml :"instances/show"
        end
        format.html do
          redirect instance_url(instance.id) if instance and instance.id
          redirect instances_url
        end
      end
    end
  end

  operation :reboot, :method => :post, :member => true do
    description "Reboot running instance"
    param :id,           :string, :required
    control { instance_action(:reboot) }
  end

  operation :start, :method => :post, :member => true do
    description "Start an instance"
    param :id,           :string, :required
    control { instance_action(:start) }
  end

  operation :stop, :method => :post, :member => true do
    description "Stop running instance"
    param :id,           :string, :required
    control { instance_action(:stop) }
  end

  operation :destroy do
    description "Destroy instance"
    param :id,           :string, :required
    control { instance_action(:destroy) }
  end
end

collection :hardware_profiles do
  description <<END
 A hardware profile represents a configuration of resources upon which a
 machine may be deployed. It defines aspects such as local disk storage,
 available RAM, and architecture. Each provider is free to define as many
 (or as few) hardware profiles as desired.
END

  operation :index do
    description "List of available hardware profiles"
    param :id,          :string
    param :architecture,  :string,  :optional,  [ 'i386', 'x86_64' ]
    control do
        @profiles = driver.hardware_profiles(credentials, params)
        respond_to do |format|
          format.xml  { haml :'hardware_profiles/index' }
          format.html  { haml :'hardware_profiles/index' }
          format.json { convert_to_json(:hardware_profile, @profiles) }
        end
    end
  end

  operation :show do
    description "Show specific hardware profile"
    param :id,          :string,    :required
    control do
      @profile =  driver.hardware_profile(credentials, params[:id])
      respond_to do |format|
        format.xml { haml :'hardware_profiles/show', :layout => false }
        format.html { haml :'hardware_profiles/show' }
        format.json { convert_to_json(:hardware_profile, @profile) }
      end
    end
  end

end

collection :storage_snapshots do
  description "Storage snapshots description here"

  operation :index do
    description "Listing of storage snapshots"
    param :id,            :string
    control { filter_all(:storage_snapshots) }
  end

  operation :show do
    description "Show storage snapshot"
    param :id,          :string,    :required
    control { show(:storage_snapshot) }
  end
end

collection :storage_volumes do
  description "Storage volumes description here"

  operation :index do
    description "Listing of storage volumes"
    param :id,            :string
    control { filter_all(:storage_volumes) }
  end

  operation :show do
    description "Show storage volume"
    param :id,          :string,    :required
    control { show(:storage_volume) }
  end
end
