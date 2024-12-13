# frozen_string_literal: true

# :markup: markdown

module ActionController
  # # Action Controller Implicit Render
  #
  # Handles implicit rendering for a controller action that does not explicitly
  # respond with `render`, `respond_to`, `redirect`, or `head`.
  #
  # For API controllers, the implicit response is always `204 No Content`.
  #
  # For all other controllers, we use these heuristics to decide whether to
  # render a template, raise an error for a missing template, or respond with
  # `204 No Content`:
  #
  # When we *do* find a template, it's rendered. Template lookup accounts for
  # the action name, locales, format, variant, template handlers, and more (see
  # {render}[rdoc-ref:ActionController::Rendering#render] for details).
  #
  # When we *do not* find a template:
  #
  # - If the controller action has templates for other formats, variants, etc.,
  #   then we trust that you meant to provide a template for this response, too,
  #   and we raise `ActionController::UnknownFormat` with an explanation.
  #
  # - If the request is a page load in a web browser (a non-XHR GET request for
  #   an HTML response) where you would expect to have rendered a template, then
  #   we raise `ActionController::MissingExactTemplate` with an explanation.
  #
  # - Otherwise, we implicitly respond with `204 No Content`.
  module ImplicitRender
    # :stopdoc:
    include BasicImplicitRender

    def default_render
      if template_exists?(action_name.to_s, _prefixes, variants: request.variant)
        render
      elsif any_templates?(action_name.to_s, _prefixes)
        message = "#{self.class.name}\##{action_name} is missing a template " \
          "for this request format and variant.\n" \
          "\nrequest.formats: #{request.formats.map(&:to_s).inspect}" \
          "\nrequest.variant: #{request.variant.inspect}"

        raise ActionController::UnknownFormat, message
      elsif interactive_browser_request?
        message = "#{self.class.name}\##{action_name} is missing a template for request formats: #{request.formats.map(&:to_s).join(',')}"
        raise ActionController::MissingExactTemplate.new(message, self.class, action_name)
      else
        logger.info "No template found for #{self.class.name}\##{action_name}, rendering head :no_content" if logger
        super
      end
    end

    def method_for_action(action_name)
      super || if template_exists?(action_name.to_s, _prefixes)
                 "default_render"
               end
    end

    private
      def interactive_browser_request?
        request.get? && request.format == Mime[:html] && !request.xhr?
      end
  end
end
