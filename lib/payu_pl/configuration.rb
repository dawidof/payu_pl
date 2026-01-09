# frozen_string_literal: true

require "i18n"

module PayuPl
  class Configuration
    attr_accessor :locale, :second_key

    def initialize
      @locale = :en
      @second_key = nil
    end
  end

  def self.config
    @config ||= Configuration.new
  end

  def self.configure
    yield(config)
  end

  def self.load_translations!
    locales_glob = File.expand_path("../../config/locales/*.yml", __dir__)
    I18n.load_path |= Dir[locales_glob]

    # Ensure the backend actually loads newly added paths.
    I18n.backend.load_translations

    # Do not overwrite user's configuration, only extend.
    I18n.available_locales = (I18n.available_locales | %i[en pl])
  end

  def self.t(key, **opts)
    I18n.t(key, **opts, scope: %i[payu_pl validation], locale: config.locale)
  end
end

PayuPl.load_translations!
