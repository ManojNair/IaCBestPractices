// Simple Go test to verify basic functionality
package test

import (
    "testing"
)

func TestBasic(t *testing.T) {
    t.Log("Basic test is working")
    
    if 1+1 != 2 {
        t.Error("Basic math failed")
    }
}
