#!/bin/bash
# Usage: bash tools/new_post.sh "Post Title"

TITLE="$1"
DATE=$(date +%Y-%m-%d)
FILENAME="_posts/${DATE}-$(echo $TITLE | tr '[:upper:]' '[:lower:]' | tr ' ' '-')".md

cat <<EOL > $FILENAME
---
layout: post
title: $TITLE
date: $(date +"%Y-%m-%d %H:%M:%S %z")
categories: []
tags: []
description:
---

Write your content here.
EOL

echo "Created new post: $FILENAME"
