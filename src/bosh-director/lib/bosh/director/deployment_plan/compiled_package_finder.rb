module Bosh::Director
  module DeploymentPlan
    class CompiledPackageFinder
      def initialize(logger)
        @logger = logger
      end

      def find_compiled_package(package, stemcell, dependency_key, cache_key, event_log_stage)
        compiled_package = find_exact_match(package, stemcell, dependency_key)
        return compiled_package if compiled_package

        compiled_package = find_newest_match(package, stemcell, dependency_key) unless package_has_source(package)
        return compiled_package if compiled_package

        fetch_from_global_cache(package, stemcell, dependency_key, cache_key, event_log_stage)
      end

      private

      def package_has_source(package)
        !package.blobstore_id.nil?
      end

      def find_exact_match(package, stemcell, dependency_key)
        Models::CompiledPackage.find(
          package_id: package.id,
          stemcell_os: stemcell.os,
          stemcell_version: stemcell.version,
          dependency_key: dependency_key,
        )
      end

      def find_newest_match(package, stemcell, dependency_key)
        compiled_packages_for_stemcell_os = Models::CompiledPackage.where(
          package_id: package.id,
          stemcell_os: stemcell.os,
          dependency_key: dependency_key,
        ).all

        compiled_package_fuzzy_matches = compiled_packages_for_stemcell_os.select do |compiled_package_model|
          Bosh::Common::Version::StemcellVersion.match(compiled_package_model.stemcell_version, stemcell.version)
        end

        compiled_package_fuzzy_matches.max_by do |compiled_package_model|
          SemiSemantic::Version.parse(compiled_package_model.stemcell_version).release.components[1] || 0
        end
      end

      def fetch_from_global_cache(package, stemcell, dependency_key, cache_key, event_log_stage)
        return unless Config.use_compiled_package_cache? && BlobUtil.exists_in_global_cache?(package, cache_key)

        event_log_stage.advance_and_track("Downloading '#{package.desc}' from global cache") do
          @logger.info(
            "Found compiled version of package '#{package.desc}'" \
              " for stemcell '#{stemcell.desc}' in global cache",
          )
          return BlobUtil.fetch_from_global_cache(package, stemcell, cache_key, dependency_key)
        end
      end
    end
  end
end
