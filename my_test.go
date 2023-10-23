package main

import (
	"testing"
)

func TestMyFunc(t *testing.T) {
	t.Fatal("Expected 2 but got 7")
}

func TestSomeOtherFunc(t *testing.T) {
	t.Logf("Test passes")
}
