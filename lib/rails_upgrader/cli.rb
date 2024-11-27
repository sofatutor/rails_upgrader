require "rails"
require "rails_erd"
require "rails_erd/domain"

module RailsUpgrader
  class CLI
    attr_reader :domain

    def self.call(model_name)
      new.upgrade(model_name.classify)
    end

    def initialize
      preload_environment
      puts "Preloading relationships..."
      @domain = RailsERD::Domain.generate
    end

    def upgrade(model_name)
      puts "Upgrading Rails..."
      upgrade_strong_params!(model_name)
      puts "Rails is upgraded!"
    end

    private

    def upgrade_strong_params(write_to_file)
      result = domain.entities.map do |entity|
        RailsUpgrader::StrongParams.new(entity).generate_method if entity.model
      end.join

      if write_to_file
        filename = "all_strong_params.rb"
        File.open(filename, "w") { |f| f.write(result) }
        puts "See the strong params result at generated file: #{filename}"
      else
        puts "\n\n==== ALL STRONG PARAMS: ====="
        puts result
        puts "============================="
      end
    end

    def upgrade_strong_params!(model_name)
      domain.entities.each do |entity|
        next unless entity.model
        next if model_name && entity.name != model_name

        entity_to_upgrade = RailsUpgrader::StrongParams.new(entity)

        unless File.file?(entity_to_upgrade.controller_path)
          puts "Skipping #{entity.name} – no controller found at #{entity_to_upgrade.controller_path}"
          next
        end

        if entity_to_upgrade.already_upgraded?
          puts "Skipping #{entity.name} – already upgraded"
          next
        end

        begin
          puts "Upgrading #{entity.name}..."
          entity_to_upgrade.update_controller_content!
          entity_to_upgrade.update_model_content!
        rescue => e
          puts "#{entity.name} failed to upgrade: #{e.message}"
          next
        end
      end
    end

    def preload_environment
      begin
        require "#{Dir.pwd}/config/environment"
      rescue LoadError => e
        puts "Rails application not found! If you're on "\
             "a Rails application, please open a Github issue: "\
             "https://github.com/ombulabs/rails_upgrader/issues"
        abort
      end

      puts "Preloading environment..."
      Rails.application.eager_load!

      if Rails.application.respond_to?(:config) && Rails.application.config
        rails_config = Rails.application.config
        if rails_config.respond_to?(:eager_load_namespaces)
          rails_config.eager_load_namespaces.each(&:eager_load!)
        end
      end
    end
  end
end
