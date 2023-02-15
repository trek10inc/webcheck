# Webcheck Docker Container
This Docker container acts as a URL check mechanism for container orchestration systems. The container is meant to be run as Kubernetes job. Once activated, the image will perform basic GET requests to a URL and exit with a return code of zero if a series of successful responses are received.

This container is configured via the use of the following environment variables.
- **INTERVAL**: How frequently (in seconds) do we run a check
- **COUNT**: Number of checks to run. If set to value greater than zero, DURATION is ignored
- **MAX_DURATION**: Set max duration to limit check script to a specific duration if COUNT is used
- **DURATION**: How long (in seconds) does the job run if COUNT is not used
- **FAILURE_LIMIT**: How many failures the check script is willing to tolerate before exiting with a non-zero return code
- **URL**: The URL to check
- **JQ_PARSER**: The jq string used by the check script to extract information from the checked URL response.
- **EXPECTED_RESPONSE**: The expected string to compare against after applying the JQ_PARSER
- **TIMEOUT**: The timeout setting for curl to use when making requests
- **DEBUG**: Set this to enable debug output


Caveats related to the check script that is run within this container.
- COUNT and DURATION variables are mutually exclusive
- Checked URLs should provide a response in JSON format
- The check script will exit with a non-zero return code when FAILURE_LIMIT has been reached

A good reference for setting environments variables for containers can be found at the following link.

[Define Environment Variables for a Container](https://kubernetes.io/docs/tasks/inject-data-application/define-environment-variable-container/)

This container was built to accompany a blog post related to using Argo Rollouts to revert failed Kubernetes deployments. Please reference the following link for more specifics on how it is used.

[Exploring GitOps with Argo Part 2](https://www.trek10.com/blog/exploring-gitops-with-argo-part-2)

An example of a job that utlizes this container looks like the following.

    apiVersion: batch/v1
    kind: Job
    metadata:
      name: rollout-webcheck-job
    spec:
      backoffLimit: 0
      template:
        metadata:
          name: rollout-webcheck-job
        spec:
          restartPolicy: Never
          containers:
          - name: webcheck
            image: public.ecr.aws/i4a3l2a7/webcheck:latest
            env:
            - name: URL
              value: 'http://192.168.0.161:30090/healthz'
            - name: INTERVAL
              value: '5'
            - name: DURATION
              value: '300'
            - name: FAILURE_LIMIT
              value: '5'
            - name: JQ_PARSER
              value: '.status'
            - name: EXPECTED_RESPONSE
              value: 'ok'
            - name: TIMEOUT
              value: '3'
