package main

import (
	"fmt"
	"os"

	"github.com/wzshiming/gh-ci-bot/internal/bot"
)

func main() {
	if err := bot.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "%v\n", err)
		os.Exit(1)
	}
}
