# This plugins lets us to write the policy YAML only once.
# It removes duplication of examples for both universal and kubernetes environments.
# The expected format is universal. It only works for policies V2 with a `spec` blocks.
require 'yaml'
module Jekyll
  module KumaPlugins
    module Liquid
      module Tags
        class PolicyYaml < ::Liquid::Block
          def initialize(tag_name, tabs_name, options)
             super
             @tabs_name = tabs_name
          end

		  # process_hash and process_array are recursive functions that remove the suffixes from the keys
		  # and rename the keys that have the suffixes.
		  # For example, if you have keys called `name_uni` and `name_kube`:
		  # on universal - `name_uni` -> `name` and `name_kube` will be removed
		  # on kuberenetes - `name_kube` -> `name` and `name_uni` will be removed
          def process_hash(hash, remove_suffix, rename_suffix)
            keys_to_remove = []
            keys_to_rename = {}

            hash.each do |key, value|
              if value.is_a?(Hash)
                process_hash(value, remove_suffix, rename_suffix)  # Recursive call for nested hash
              elsif value.is_a?(Array)
                process_array(value, remove_suffix, rename_suffix)  # Recursive call for nested array
              end

              if key.end_with?(remove_suffix)
                keys_to_remove << key
              elsif key.end_with?(rename_suffix)
                new_key = key.sub(/#{rename_suffix}\z/, '')
                keys_to_rename[key] = new_key
              end
            end

            keys_to_remove.each { |key| hash.delete(key) }
            keys_to_rename.each { |old_key, new_key| hash[new_key] = hash.delete(old_key) }
          end

          def process_array(array, remove_suffix, rename_suffix)
            array.each do |item|
              if item.is_a?(Hash)
                process_hash(item, remove_suffix, rename_suffix)  # Recursive call for nested hash in array
              elsif item.is_a?(Array)
                process_array(item, remove_suffix, rename_suffix)  # Recursive call for nested array
              end
            end
          end

          def render(context)
            content = super
            return "" unless content != ""
            site_data = context.registers[:site].config
            mesh_namespace = site_data['mesh_namespace']
            # remove ```yaml header and ``` footer
            pure_yaml = content.gsub(/`{3}yaml\n/, '').gsub(/`{3}/, '')
            yaml_data = YAML.load(pure_yaml)
            kube_hash = {
              "apiVersion" => "kuma.io/v1alpha1",
              "kind" => yaml_data["type"],
              "metadata" => {
                "name" => yaml_data["name"],
                "namespace" => mesh_namespace,
                "labels" => {
                  "kuma.io/mesh" => yaml_data["mesh"]
                }
              },
              "spec" => yaml_data["spec"]
            }
            process_hash(kube_hash, "_uni", "_kube")
            # remove `---` header and end line generated by YAML.dump
            kube_yaml = YAML.dump(kube_hash).gsub(/^---\n/, '').chomp

			uni_data = YAML.load(pure_yaml) # load again so we don't have to deep copy kube_hash
            process_hash(uni_data, "_kube", "_uni")
            uni_yaml = YAML.dump(uni_data).gsub(/^---\n/, '').chomp

            htmlContent = "
{% tabs #{@tabs_name} useUrlFragment=false %}
{% tab #{@tabs_name} Kubernetes %}
```yaml
#{kube_yaml}
```
{% endtab %}
{% tab #{@tabs_name} Universal %}
```yaml
#{uni_yaml}
```
{% endtab %}
{% endtabs %}"
            ::Liquid::Template.parse(htmlContent).render(context)
          end
        end
      end
    end
  end
end

Liquid::Template.register_tag('policy_yaml', Jekyll::KumaPlugins::Liquid::Tags::PolicyYaml)