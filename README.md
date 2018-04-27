# buildkite-docker-bootstrap

Demo of how to run an entire Buildkite job (including hooks) in a Docker container.

## How it works

When a build agent starts up, the [`buildkite-elastic-bootstrap` script](buildkite-elastic-bootstrap) configures the Buildkite agent to use the [`buildkite-docker-bootstrap` script](buildkite-docker-bootstrap), which executes the job in a Docker container.

### Unprivileged users

Because the job is bootstrapped inside the container, the workdir does not have to be bind-mounted from the host (unlike when using the [Docker plugin](https://github.com/buildkite-plugins/docker-buildkite-plugin)).
This means the user inside the container owns all the checked-out files so doesn't need to be root or to match the user on the host to access them.

The user will need to belong to the `docker` group on the host if the Docker socket is bind-mounted into the container for Docker-outside-of-Docker builds.
`buildkite-docker-bootstrap` passes the [`--group-add`](https://docs.docker.com/engine/reference/run/#additional-groups) option to `docker run` to ensure that the user has the necessary permissions.
Unfortunately, this requires user namespace remapping to be disabled.
