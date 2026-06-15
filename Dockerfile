FROM mono:6.12
RUN sed -i 's/deb.debian.org/archive.debian.org/g' /etc/apt/sources.list && \
    sed -i '/buster-updates/d' /etc/apt/sources.list && \
    sed -i 's|security.debian.org/debian-security|archive.debian.org/debian-security|g' /etc/apt/sources.list && \
    apt-get update && apt-get install -y mono-xsp4 && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY . .
RUN mkdir -p bin && mcs -target:library -out:bin/ZavaLoanPortal.dll \
    -reference:System.dll -reference:System.Web.dll -reference:System.Data.dll \
    -reference:System.Configuration.dll -reference:System.Web.Extensions.dll \
    -reference:System.Xml.dll -reference:System.Xml.Linq.dll -reference:System.Net.Http.dll \
    $(find . -name "*.cs" -not -path "./obj/*")
EXPOSE 8080
CMD ["xsp4", "--port", "8080", "--address", "0.0.0.0", "--nonstop"]
