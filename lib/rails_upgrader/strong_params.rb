require "active_model/naming"

module RailsUpgrader
  class StrongParams
    attr_reader :entity, :param_key, :controller_path, :model_path
    ATTR_ACCESSIBLES = /\s+attr_accessible\s+([:]\w+[,]?\s+)+/.freeze

    def initialize(entity)
      @entity = entity
      @param_key = ActiveModel::Naming.param_key(entity.model)
      @controller_paths = find_controllers
      @model_path = "app/models/#{param_key}.rb"
    end

    def already_upgraded?
      model_content.match(ATTR_ACCESSIBLES).nil? ||
        controller_paths.all? { |path| controller_content(path).include?("def #{param_key}_params") }
    end

    def update_controller_content!
      for path in controller_paths
        puts "- Adding strong params to #{path}..."
        updated_content = appended_strong_params(path)

        File.open(path, 'wb') do |file|
        file.write(updated_content)
        end
      end
    end

    def update_model_content!
      puts "- Removing attr_accessible from #{model_path}..."
      updated_content = removed_attr_accessible

      File.open(model_path, 'wb') do |file|
        file.write(updated_content)
      end
    end

    def generate_method
      result = "  def #{param_key}_params\n"
      result += "    params.require(:#{param_key})\n"

      param_list = entity.attributes.reject do |attribute|
        attribute.to_s =~ /^id$|^type$|^created_at$|^updated_at$|_token$|_count$/
      end.map { |attribute| ":#{attribute}" }.join(", ")
      result += "          .permit(#{param_list})\n"

      if entity.model.nested_attributes_options.present?
        result += "  # TODO: check nested attributes for: #{entity.model.nested_attributes_options.keys.join(', ')}\n"
      end
      result += "  end\n\n"
      result
    end

    private

      def find_controllers
        Dir.glob("app/controllers/**/#{param_key.pluralize}_controller.rb")
      end

      def appended_strong_params(path)
        result = controller_content(path)
        last_end = result.rindex("end")
        result[last_end..last_end+3] = "\n#{generate_method}end\n"
        result
      end

      def removed_attr_accessible
        result = model_content
        result[ATTR_ACCESSIBLES] = "\n"
        result
      end

      def controller_content(path)
        File.read(path)
      end

      def model_content
        File.read(model_path)
      end
  end
end
