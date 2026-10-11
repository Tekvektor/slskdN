#!/usr/bin/env node
// Copyright (c) slskdN Team. All rights reserved.
import { main } from './validation-engine/engine.mjs';

main().then((code) => {
  process.exitCode = code;
}).catch((error) => {
  process.stderr.write(String(error?.stack ?? error) + '\n');
  process.exitCode = 1;
});
