FROM debian:stable-slim AS build
WORKDIR /opt
RUN apt update -y && apt install make yasm binutils -y
COPY . .
RUN make release

FROM scratch
COPY --from=build /opt/asmttpd /
COPY --from=build /opt/web_root /web_root
ENTRYPOINT ["/asmttpd"]
CMD ["/web_root", "80"]