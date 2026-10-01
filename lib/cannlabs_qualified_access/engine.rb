# frozen_string_literal: true

module CannLabsQualifiedAccess
  class Engine < ::Rails::Engine
    engine_name CannLabsQualifiedAccess::PLUGIN_NAME

    initializer "cannlabs_qualified_access.scheduled_jobs", before: :setup_main_autoloader do |app|
      scheduled_jobs = config.root.join("app/jobs/scheduled")
      Rails.autoloaders.main.eager_load_dir(scheduled_jobs) if scheduled_jobs.directory?
    end
  end
end
