# frozen_string_literal: true
module Blacklight
  # Presents a single document on the results page
  class IndexPresenter
    attr_reader :document, :configuration, :view_context

    # @param [SolrDocument] document
    # @param [#blacklight_config, #document_index_view_type, #url_for_document, #session_tracking_params] view_context scope for linking and generating urls
    # @param [Blacklight::Configuration] configuration
    def initialize(document, view_context, configuration = view_context.blacklight_config)
      @document = document
      @view_context = view_context
      @configuration = configuration
    end

    # link_to_document('VIEW', :counter => 3)
    # Use the catalog_path RESTful route to create a link to the show page for a specific item.
    # catalog_path accepts a hash. The solr query params are stored in the session,
    # so we only need the +counter+ param here. We also need to know if we are viewing to document as part of search results.
    def link_to_document(field_or_opts = nil, opts={ :counter => nil })
      if field_or_opts.is_a? Hash
        opts = field_or_opts
      else
        field = field_or_opts
      end

      view_context.link_to(label(field, opts),
                           view_context.url_for_document(document),
                           document_link_params(opts))
    end

    ##
    # Render the document index heading
    #
    # @param [Symbol, Proc, String] field_or_string_or_proc Render the given field or evaluate the proc or render the given string. if nil it defaults to calling _show_link_field_
    # @param [Hash] opts
    def label(field_or_string_or_proc = nil, opts = {})
      field_or_string_or_proc ||= show_link_field
      config = Configuration::NullField.new
      value = case field_or_string_or_proc
                when Symbol
                  config = field_config(field_or_string_or_proc)
                  document[field_or_string_or_proc]
                when Proc
                  field_or_string_or_proc.call(document, opts)
                when String
                  field_or_string_or_proc
              end

      value ||= document.id
      build_field_presenter(config).value(value: value)
    end

    ##
    # Determine whether to render a given field in the index view.
    #
    # @param [Blacklight::Configuration::Field] field_config
    # @return [Boolean]
    def render_field? field_config
      view_context.should_render_field?(field_config, document) &&
        view_context.document_has_value?(document, field_config)
    end

    # @yields [Configuration::IndexField] each of the fields that should be rendered
    def fields
      configuration.index_fields.values.each do |field|
        yield(build_field_presenter(field)) if render_field?(field)
      end
    end

    # @param [Configuration::IndexField]
    # @return [IndexFieldPresenter]
    def build_field_presenter(field)
      IndexFieldPresenter.new(self, field)
    end

    # Used in the document list partial (search view) for creating a link to the document show action
    def show_link_field
      fields = Array(view_configuration.title_field)
      field = fields.find { |f| document.has? f }
      field &&= field.try(:to_sym)
      field ||= document.id
      field
    end

    # TODO: perhaps the view_type can be passed in on initialize
    def view_type
      view_context.document_index_view_type
    end

    private

      def index_field(field)
        configuration.index_fields[field]
      end

      def document_link_params(opts)
        view_context.session_tracking_params(document, opts[:counter]).deep_merge(opts.except(:label, :counter))
      end

      # TODO: perhaps the view_configuration can be passed in on initialize
      def view_configuration
        configuration.view_config(view_type)
      end

      def field_config(field)
        configuration.index_fields.fetch(field) { Configuration::NullField.new(field) }
      end
  end
end
