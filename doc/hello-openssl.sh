#!/bin/bash
generateRootCa() {
  echo "1 Generate CA private key:"
  openssl genrsa -out hello-ca.key 2048 
  echo "2 Generate CSR(certificate signing request):"
  openssl req -new -key hello-ca.key -out hello-ca.csr -subj "/C=CN/ST=BJ/L=BJ/O=feuyeux/OU=dev"
  echo "3 Generate Self Signed certificate"
  openssl x509 -req -days 365 -in hello-ca.csr -signkey hello-ca.key -out hello-ca.crt
}
generateUserCertificate() {
  echo "[${user_ct}] 1 Generate server private key:"
  openssl genrsa -out ${user_ct}.key 2048
  echo "[${user_ct}] 2 Generate CSR(certificate signing request):"
  openssl req -new -key ${user_ct}.key -out ${user_ct}.csr -subj "/C=CN/ST=BJ/L=BJ/O=feuyeux/OU=dev"
  #-addext "subjectAltName = DNS:localhost,IP:127.0.0.1"
  #-reqexts SAN \
  #-config <(cat /etc/ssl/openssl.cnf <(printf "[SAN]\nsubjectAltName='DNS:localhost,IP:127.0.0.1'"))
  echo "[${user_ct}] 3 Generate a certificate signing request based on an existing certificate:"
  openssl x509 -req \
  -extfile <(printf "subjectAltName=DNS:localhost,IP:127.0.0.1") \
  -days 365 \
  -in ${user_ct}.csr \
  -CA hello-ca.crt \
  -CAkey hello-ca.key \
  -CAcreateserial \
  -out ${user_ct}.crt

  openssl rsa -in ${user_ct}.key -text > ${user_ct}-key.pem
  openssl x509 -in ${user_ct}.crt -out ${user_ct}-crt.pem
}
generateKeyStore() {
  echo "[${user_ct}] 1 Convert crt to pem:"
  openssl x509 -in hello-ca.crt -out hello-ca-crt.pem
  echo "[${user_ct}] 2 Generate pkcs12:"
  openssl pkcs12 -export -in ${user_ct}.crt \
  -inkey ${user_ct}.key \
  -out ${user_ct}.p12 \
  -name ${user_ct} \
  -CAfile hello-ca-crt.pem \
  -caname hello-root \
  -passout pass:secret
  echo "[${user_ct}] 3 Generate keystore:"
  keytool -importkeystore \
  -srckeystore ${user_ct}.p12 \
  -srcstoretype PKCS12 \
  -destkeystore ${user_ct}-keystore.jks \
  -srcstorepass secret \
  -deststorepass secret
  echo "[${user_ct}] 4 Generate truststore:"
  keytool -keystore ${user_ct}-truststore.jks \
  -importcert \
  -file hello-ca-crt.pem \
  -alias hello-ca \
  -storepass secret \
  -noprompt
}
verify() {
  echo "1 private key:"
  openssl rsa -check -in hello-ca.key
  openssl rsa -check -in hello-server.key
  openssl rsa -check -in hello-client.key
  echo
  echo "2 csr:"
  openssl req -text -noout -verify -in hello-ca.csr
  openssl req -text -noout -verify -in hello-server.csr
  openssl req -text -noout -verify -in hello-client.csr
  echo
  echo "3 crt:"
  openssl x509 -in hello-ca.crt -text -noout
  openssl x509 -in hello-server.crt -text -noout
  openssl x509 -in hello-client.crt -text -noout
  echo
  echo "4 p12:"
  openssl pkcs12 -info -noout -in hello-server.p12 -passin pass:secret
  openssl pkcs12 -info -noout -in hello-client.p12 -passin pass:secret
  echo
  echo "5 jks:"
  keytool -list -v -keystore hello-server-keystore.jks -storepass secret
  keytool -list -v -keystore hello-server-truststore.jks -storepass secret
  keytool -list -v -keystore hello-client-truststore.jks -storepass secret
  keytool -list -v -keystore hello-client-keystore.jks -storepass secret
}
clean() {
  rm -rf hello-ca*
  rm -rf hello-server*
  rm -rf hello-client*
}

clean
echo "========= 1 ROOT CA ========="
generateRootCa
echo
echo "========= 2 Server CRT ========="
export user_ct=hello-server
generateUserCertificate
echo
echo "========= 3 Server JKS ========="
generateKeyStore
echo
echo "========= 4 Client CRT ========="
export user_ct=hello-client
generateUserCertificate
echo
echo "========= 5 Client JKS ========="
generateKeyStore
echo
echo "========= 6 Verify ========="
verify