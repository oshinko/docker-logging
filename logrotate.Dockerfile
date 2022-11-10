FROM debian:bookworm-slim
RUN apt update -y && \
    apt install -y logrotate
