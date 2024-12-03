require "active_model/naming"

module RailsUpgrader
  class StrongParams
    attr_reader :entity, :param_key, :controller_paths, :model_path
    ATTR_ACCESSIBLES = %r{
      ^
      \ * attr_accessible \ +
      (  # attributes
        (?:
          : \w+
          (?:  # comma with optional comment
            , (?: \ * \# .* )? \s*
          )?
        )++
      )
      (?! as: )  # no support for roles yet
      (?: \ * \# .* )?  # optional final comment
      \n+
    }x

    def initialize(entity)
      @entity = entity
      @param_key = ActiveModel::Naming.param_key(entity.model)
      @controller_paths = find_controllers
      @model_path = "app/models/#{param_key}.rb"
    end

    def exists?
      File.exist?(model_path)
    end

    def already_upgraded?
      model_content.match(ATTR_ACCESSIBLES).nil?
    end

    def update_controller_content!
      for path in controller_paths
        puts "- Adding strong params to #{path}"
        updated_content = appended_strong_params(path)

        File.open(path, 'wb') do |file|
          file.write(updated_content)
        end
      end
    end

    def update_model_content!
      puts "- Removing attr_accessible from #{model_path}"
      updated_content = removed_attr_accessible

      File.open(model_path, 'wb') do |file|
        file.write(updated_content)
      end
    end

    def generate_method
      result = "  def #{param_key}_params\n"
      result += "    params.require(:#{param_key})\n"

      accessible_attributes = model_content.scan(ATTR_ACCESSIBLES).last.first
      result += "          .permit(#{accessible_attributes.strip})\n"

      if entity.model.nested_attributes_options.present?
        result += "  # TODO: check nested attributes for: #{entity.model.nested_attributes_options.keys.join(', ')}\n"
      end
      result += "  end\n"
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
        model_content.gsub(/(^ *# attr_accessible\s*)?#{ATTR_ACCESSIBLES}/, "")
      end

      def controller_content(path)
        File.read(path)
      end

      def model_content
        @model_content ||= File.read(model_path)
      end
  end
end
