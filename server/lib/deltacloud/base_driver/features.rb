require 'deltacloud/validation'

# Add advertising of optional features to the base driver
module Deltacloud

  class FeatureError < StandardError; end
  class DuplicateFeatureDeclError < FeatureError; end
  class UndeclaredFeatureError < FeatureError; end

  class BaseDriver

    # An operation on a collection like cretae or show. Features
    # can add parameters to operations
    class Operation
      attr_reader :name

      include Deltacloud::Validation

      def initialize(name, &block)
        @name = name
        @params = {}
        instance_eval &block
      end
    end

    # The declaration of a feature, defines what operations
    # are modified by it
    class FeatureDecl
      attr_reader :name, :operations

      def initialize(name, &block)
        @name = name
        @operations = []
        instance_eval &block
      end

      def description(text=nil)
        @description = text if text
        @description
      end

      # Add a new operation or modify an existing one through BLOCK
      def operation(name, &block)
        unless op = @operations.find { |op| op.name == name }
          op = Operation.new(name, &block)
          @operations << op
        else
          op.instance_eval(&block) if block_given?
        end
        op
      end
    end

    # A specific feature enabled by a driver (see +feature+)
    class Feature
      attr_reader :decl

      def initialize(decl, &block)
        @decl = decl
        instance_eval &block if block_given?
      end

      def name
        decl.name
      end

      def operations
        decl.operations
      end

      def description
        decl.description
      end
    end

    def self.feature_decls
      @@feature_decls ||= {}
    end

    def self.feature_decl_for(collection, name)
      decls = feature_decls[collection]
      if decls
        decls.find { |dcl| dcl.name == name }
      else
        nil
      end
    end

    # Declare a new feature
    def self.declare_feature(collection, name, &block)
      feature_decls[collection] ||= []
      raise DuplicateFeatureDeclError if feature_decl_for(collection, name)
      feature_decls[collection] << FeatureDecl.new(name, &block)
    end

    def self.features
      @@features ||= {}
    end

    # Declare in a driver that it supports a specific feature
    #
    # The same feature can be declared multiple times in a driver, so that
    # it can be changed successively by passing in different blocks.
    def self.feature(collection, name, &block)
      features[collection] ||= []
      if f = features[collection].find { |f| f.name == name }
        f.instance_eval(&block) if block_given?
        return f
      end
      unless decl = feature_decl_for(collection, name)
        raise UndeclaredFeatureError, "No feature #{name} for #{collection}"
      end
      features[collection] << Feature.new(decl, &block)
    end

    def features(collection)
      self.class.features[collection] || []
    end

    #
    # Declaration of optional features
    #
    declare_feature :instances, :user_name do
      description "Accept a user-defined name on instance creation"
      operation :create do
        param :name, :string, :optional, nil,
        "The user-defined name"
      end
    end

    declare_feature :instances, :user_data do
      description "Make user-defined data available on a special webserver"
      operation :create do
        param :user_data, :string, :optional, nil,
        "Base64 encoded user data will be published to internal webserver"
      end
    end

    declare_feature :instances, :authentication_key do
      operation :create do
        param :keyname, :string,  :optional, nil
        "EC2 key authentification method"
      end
      operation :show do
      end
    end

    declare_feature :instances, :authentication_password do
      operation :create do
        param :password, :string, :optional
      end
    end

    declare_feature :instances, :hardware_profiles do
      description "Size instances according to changes to a hardware profile"
      # The parameters are filled in from the hardware profiles
    end
  end
end
