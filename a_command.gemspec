# frozen_string_literal: true

require_relative "lib/a_command/version"

Gem::Specification.new do |spec|
  spec.name          = "a_command"
  spec.version       = ACommand::VERSION
  spec.authors       = ["Yury Ivannikov"]
  spec.email         = ["yi@ariv.al"]

  spec.summary       = "ACommand gem"
  spec.description   = "Command pattern implementation (0-dependency)"
  spec.homepage      = "https://github.com/Scumfunk/a_command"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.4.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/Scumfunk/a_command"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.require_paths = ["lib"]
end
