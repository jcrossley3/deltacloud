#
# Copyright (C) 2009  Red Hat, Inc.
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA


require 'deltacloud/base_driver'

module ConversionHelper

  def convert_to_json(type, obj)
    if ( [ :flavor, :account, :image, :realm, :instance, :storage_volume, :storage_snapshot, :hardware_profile ].include?( type ) )
      if Array.eql?(obj.class)
        data = obj.collect do |o|
          o.to_hash.merge({ :href => self.send(:"#{type}_url", type.eql?(:hardware_profile) ? o.name : o.id ) })
        end
        type = type.to_s.pluralize
      else
        data = obj.to_hash
        data.merge!({ :href => self.send(:"#{type}_url", data[:id]) })
      end
      return { :"#{type}" => data }.to_json
    end
  end

end
