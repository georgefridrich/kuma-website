# This plugins lets us add a set of key values to add to install and it will generate 2 tabs for helm and kumactl install
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
             name, *params_list = @markup.split(' ')
             params = {'prefixed' => "true"}
             params_list.each do |item|
                 sp = item.split('=')
                 params[sp[0]] = sp[1] unless sp[1] == ''
             end
             @prefixed = params['prefixed'].downcase() == "true"
          end

          def render(context)
            content = super
            return "" unless content != ""
            site_data = context.registers[:site].config

            opts = content.strip.split("\n").map do |x|
                x = site_data['set_flag_values_prefix'] + x if @prefixed
                "--set \"#{x}\""
            end
            res = opts.join(" \\\n  ")

            htmlContent = "
{% tabs #{@tabs_name} useUrlFragment=false %}
{% tab #{@tabs_name} kumactl %}
```shell
kumactl install control-plane \\
  #{res} \\
  | kubectl apply -f -
```
{% endtab %}
{% tab #{@tabs_name} helm %}
```shell
helm install --create-namespace \\
  #{res} \\
  {{site.mesh_helm_install_name}} {{site.mesh_helm_repo}}
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

Liquid::Template.register_tag('cpinstall', Jekyll::KumaPlugins::Liquid::Tags::PolicyYaml)