package source

import (
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"encoding/pem"
	"os"
	"path/filepath"
	"testing"
)

func TestParsePrivateKeySigner_Unencrypted(t *testing.T) {
	key := mustGenerateRSAPrivateKeyPEM(t, "")

	if _, err := parsePrivateKeySigner(key, ""); err != nil {
		t.Fatalf("expected unencrypted key to parse, got error: %v", err)
	}
}

func TestParsePrivateKeySigner_EncryptedWithPassphrase(t *testing.T) {
	key := mustGenerateRSAPrivateKeyPEM(t, "secret")

	if _, err := parsePrivateKeySigner(key, "secret"); err != nil {
		t.Fatalf("expected encrypted key to parse with passphrase, got error: %v", err)
	}
}

func TestResolveKeyFilePath_ExpandHomeAndEnv(t *testing.T) {
	home, err := os.UserHomeDir()
	if err != nil {
		t.Skipf("skip: cannot get user home dir: %v", err)
	}

	if got := resolveKeyFilePath("~/id_rsa"); got != filepath.Join(home, "id_rsa") {
		t.Fatalf("unexpected expanded path: %s", got)
	}

	t.Setenv("SFTP_KEY_DIR", "/tmp/sftp-key-dir")
	if got := resolveKeyFilePath("$SFTP_KEY_DIR/id_rsa"); got != "/tmp/sftp-key-dir/id_rsa" {
		t.Fatalf("unexpected env-expanded path: %s", got)
	}
}

func mustGenerateRSAPrivateKeyPEM(t *testing.T, passphrase string) []byte {
	t.Helper()

	privateKey, err := rsa.GenerateKey(rand.Reader, 1024)
	if err != nil {
		t.Fatalf("generate rsa key: %v", err)
	}

	pemBlock := &pem.Block{
		Type:  "RSA PRIVATE KEY",
		Bytes: x509.MarshalPKCS1PrivateKey(privateKey),
	}

	if passphrase != "" {
		encrypted, err := x509.EncryptPEMBlock(rand.Reader, pemBlock.Type, pemBlock.Bytes, []byte(passphrase), x509.PEMCipherAES256)
		if err != nil {
			t.Fatalf("encrypt pem: %v", err)
		}
		pemBlock = encrypted
	}

	return pem.EncodeToMemory(pemBlock)
}
