REPOSITORY = ENV['DOCKER_REPOSITORY'] || 'vladgh'
REPOSITORY_PREFIX = ENV['REPOSITORY_PREFIX'] || 'vpm'
NO_CACHE = ENV['DOCKER_NO_CACHE'] || false

require 'mkmf'

IMAGES = Dir.glob('docker_images/*').select do |dir|
  File.directory?(dir) && File.exist?("#{dir}/Dockerfile")
end

task :docker do
  unless find_executable 'docker'
    raise 'These tasks require docker to be installed'
  end
end

namespace :docker do
  desc 'List all Docker images'
  task :list do
    info IMAGES.map { |image| File.basename(image) }
  end

  desc 'Garbage collect unused docker filesystem layers'
  task gc: :docker do
    unless `docker images -f "dangling=true" -q`.empty?
      sh 'docker rmi $(docker images -f "dangling=true" -q)'
    end
  end

  IMAGES.each do |image|
    name = File.basename(image)
    path = "#{REPOSITORY}/#{REPOSITORY_PREFIX}-#{name}"

    namespace name.to_sym do |_args|
      RSpec::Core::RakeTask.new(spec: [:docker]) do |t|
        t.pattern = "#{image}/spec/*_spec.rb"
      end

      desc 'Run Hadolint against the Dockerfile'
      task lint: :docker do
        info "Running Hadolint to check the style of #{image}/Dockerfile"
        sh "docker run --rm -i lukasmartinelli/hadolint < #{image}/Dockerfile"
      end

      desc 'Build docker image'
      task build: :docker do
        info "Building #{path}:latest"
        cmd = "cd #{image} && docker build -t #{path}:latest"
        info "Ignoring layer cache for #{path}" if NO_CACHE
        cmd += ' --no-cache' if NO_CACHE
        sh "#{cmd} ."
        if version
          info "Building #{path}:#{version}"
          sh "cd #{image} && docker build -t #{path}:#{version} ."
        end
      end

      desc 'Publish docker image'
      task publish: :docker do
        if version
          info "Pushing #{path}:#{version} to Docker Hub"
          sh "docker push '#{path}:#{version}'"
        else
          warn "No version specified in Dockerfile for #{path}"
        end
        info "Pushing #{path}:latest to Docker Hub"
        sh "docker push '#{path}:latest'"
      end
    end
  end

  [:lint, :build, :publish].each do |task_name|
    desc "Run #{task_name} for all images in repository in parallel"
    multitask task_name => IMAGES
      .collect { |image| "#{File.basename(image)}:#{task_name}" }
  end

  desc 'Run syntax and lint tests.'
  task test: [
    :rubocop,
    :lint
  ]
end
