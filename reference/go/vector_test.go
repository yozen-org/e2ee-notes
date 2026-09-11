package reference

import (
	"crypto/aes"
	"crypto/cipher"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"os"
	"testing"
)

// Dartと共有する固定ベクターから、暗号化検証に必要な値を読み込む。
type vector struct {
	VaultKeyHex     string `json:"vaultKeyHex"`
	ObjectID        string `json:"objectID"`
	NonceHex        string `json:"nonceHex"`
	AADBase64       string `json:"aadBase64"`
	PlaintextBase64 string `json:"plaintextBase64"`
	EncryptedObject struct {
		Ciphertext string `json:"ciphertext"`
	} `json:"encryptedObject"`
}

// Go標準ライブラリで同じ暗号文が得られ、元の平文へ復号できることを検証する。
func TestOperationCreateVector(t *testing.T) {
	data, err := os.ReadFile("../../spec/test-vectors/operation-create-v1.json")
	if err != nil {
		t.Fatal(err)
	}
	var fixture vector
	if err := json.Unmarshal(data, &fixture); err != nil {
		t.Fatal(err)
	}
	key, err := hex.DecodeString(fixture.VaultKeyHex)
	if err != nil {
		t.Fatal(err)
	}
	nonce, err := hex.DecodeString(fixture.NonceHex)
	if err != nil {
		t.Fatal(err)
	}
	aad, err := base64.StdEncoding.DecodeString(fixture.AADBase64)
	if err != nil {
		t.Fatal(err)
	}
	plaintext, err := base64.StdEncoding.DecodeString(fixture.PlaintextBase64)
	if err != nil {
		t.Fatal(err)
	}

	block, err := aes.NewCipher(key)
	if err != nil {
		t.Fatal(err)
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		t.Fatal(err)
	}
	sealed := gcm.Seal(nil, nonce, plaintext, aad)
	if got := base64.StdEncoding.EncodeToString(sealed); got != fixture.EncryptedObject.Ciphertext {
		t.Fatalf("ciphertext mismatch\ngot:  %s\nwant: %s", got, fixture.EncryptedObject.Ciphertext)
	}
	opened, err := gcm.Open(nil, nonce, sealed, aad)
	if err != nil {
		t.Fatal(err)
	}
	if string(opened) != string(plaintext) {
		t.Fatal("plaintext mismatch")
	}
}
