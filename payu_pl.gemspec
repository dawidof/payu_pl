# frozen_string_literal: true

require_relative "lib/payu_pl/version"

Gem::Specification.new do |spec|
  spec.name = "payu_pl"
  spec.version = PayuPl::VERSION
  spec.authors = ["Dmytro Koval"]
  spec.email = ["dawidofdk@o2.pl"]

  spec.summary = "PayU Poland (PayU GPO Europe) REST API client"
  spec.description = "A small Ruby client for the PayU GPO Europe REST API (Poland), with basic operations, validation and error handling."
  spec.homepage = "https://developers.payu.com/europe/"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/dawidof/payu_pl"
  spec.metadata["changelog_uri"] = "https://github.com/dawidof/payu_pl/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "dry-initializer", "~> 3.1"
  spec.add_dependency "dry-validation", "~> 1.10"
  spec.add_dependency "i18n", "~> 1.14"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
