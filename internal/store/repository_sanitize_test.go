package store

import "testing"

func TestSanitizeUTF8RemovesNUL(t *testing.T) {
	input := "abc\x00def"
	if got := sanitizeUTF8(input); got != "abcdef" {
		t.Fatalf("sanitizeUTF8() = %q, want %q", got, "abcdef")
	}
}

func TestSanitizeLogRecordRemovesNULFromTextFields(t *testing.T) {
	log := sanitizeLogRecord(NginxLogRecord{
		IP:               "127.0.0.1\x00",
		Method:           "GE\x00T",
		Url:              "/foo\x00/bar",
		UpstreamAddr:     "10.0.0.1:80\x00",
		Host:             "exa\x00mple.com",
		RequestID:        "req\x00-1",
		Referer:          "https://exa\x00mple.com",
		UserBrowser:      "Mozi\x00lla",
		UserOs:           "Ma\x00cOS",
		UserDevice:       "Desk\x00top",
		DomesticLocation: "浙\x00江",
		GlobalLocation:   "中\x00国",
	})

	if log.IP != "127.0.0.1" {
		t.Fatalf("IP = %q", log.IP)
	}
	if log.Method != "GET" {
		t.Fatalf("Method = %q", log.Method)
	}
	if log.Url != "/foo/bar" {
		t.Fatalf("Url = %q", log.Url)
	}
	if log.UpstreamAddr != "10.0.0.1:80" {
		t.Fatalf("UpstreamAddr = %q", log.UpstreamAddr)
	}
	if log.Host != "example.com" {
		t.Fatalf("Host = %q", log.Host)
	}
	if log.RequestID != "req-1" {
		t.Fatalf("RequestID = %q", log.RequestID)
	}
	if log.Referer != "https://example.com" {
		t.Fatalf("Referer = %q", log.Referer)
	}
	if log.UserBrowser != "Mozilla" {
		t.Fatalf("UserBrowser = %q", log.UserBrowser)
	}
	if log.UserOs != "MacOS" {
		t.Fatalf("UserOs = %q", log.UserOs)
	}
	if log.UserDevice != "Desktop" {
		t.Fatalf("UserDevice = %q", log.UserDevice)
	}
	if log.DomesticLocation != "浙江" {
		t.Fatalf("DomesticLocation = %q", log.DomesticLocation)
	}
	if log.GlobalLocation != "中国" {
		t.Fatalf("GlobalLocation = %q", log.GlobalLocation)
	}
}
