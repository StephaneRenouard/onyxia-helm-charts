## PREMYOM version of vscode with fuse support

FROM inseefrlab/onyxia-vscode-python:py3.13.5

USER root

# Remove PPAs for build 
RUN rm -f /etc/apt/sources.list.d/ubuntugis-ubuntu-ppa-noble.sources

# Add s3 fuse fs for mounting S3 buckets
RUN apt-get update && \
    apt-get install -y s3fs fuse && \
    rm -rf /var/lib/apt/lists/*

# Entry point: script qui monte le bucket S3 (via s3fs) puis lance code-server
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER onyxia

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

