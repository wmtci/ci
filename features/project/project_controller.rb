require_relative "../../shared/controller_base"

module FastlaneCI
  class ProjectController < ControllerBase
    HOME = "/projects"

    # Note: The order IS important for Sinatra, so this has to be
    # above the other URL
    #
    # TODO: this should actually be a POST request
    get "#{HOME}/*/trigger" do |project_id|
      # TODO: fetching the project always like this, unify it
      project = Services::CONFIG_SERVICE.projects(FastlaneCI::GitHubSource.source_from_session(session)).find { |a| a.id == project_id }
      # TODO: Verify access to project here also
      repo = project.repo

      # TODO: Obviously we're not gonna run fastlane
      # - on the web thread
      # - through a shell command, but using a socket instead
      # but this is just for the prototype (best type)
      # So all the code below can basically be moved over
      # to some kind of job queue that will be worked off

      current_sha = repo.git.log.first.sha
      # Tell GitHub we're running CI for this...
      FastlaneCI::GitHubSource.source_from_session(session).set_build_status!(
        repo: project.repo_url,
        sha: current_sha,
        state: :pending,
        target_url: nil
      )

      begin
        Dir.chdir(repo.path) do
          Bundler.with_clean_env do
            cmd = TTY::Command.new
            # cmd.run("bundle update")
            # cmd.run("bundle exec fastlane tests")
          end
        end
      rescue StandardError => ex
        # TODO: this will be refactored anyway, to the proper fastlane runner
      end

      FastlaneCI::GitHubSource.source_from_session(session).set_build_status!(
        repo: project.repo_url,
        sha: current_sha,
        state: :success,
        target_url: nil
      )
      # We don't even need danger to post test results
      # we can post the test results as a nice table as a GitHub comment
      # easily here, as we already have access to the test failures
      # None of the CI does that for whatever reason, but we can actually show the messages

      # redirect("#{HOME}/#{project_id}")
      "All done"
    end

    get "#{HOME}/*" do |project_id|
      project = Services::CONFIG_SERVICE.projects(FastlaneCI::GitHubSource.source_from_session(session)).find { |a| a.id == project_id }
      # TODO: Verify access to project here also

      # TODO: don't hardcode this
      builds = [
        FastlaneCI::Build.new(
          project: project,
          number: 1,
          status: :failure,
          timestamp: Time.now
        ),
        FastlaneCI::Build.new(
          project: project,
          number: 2,
          status: :success,
          timestamp: Time.now
        ),
        FastlaneCI::Build.new(
          project: project,
          number: 3,
          status: :success,
          timestamp: Time.now
        ),
        FastlaneCI::Build.new(
          project: project,
          number: 4,
          status: :in_progress,
          timestamp: Time.now
        )
      ]
      project.builds = builds.reverse # TODO: just for now for the dummy data

      locals = {
        project: project,
        title: "Project #{project.project_name}"
      }
      erb(:project, locals: locals, layout: FastlaneCI.default_layout)
    end
  end
end