import { DefaultSandbox, defineSandbox } from "eve/sandbox";

// Installs what every job needs once, at build time; eve snapshots the result (Vercel Sandbox on
// Vercel, a Docker image locally), so each job starts with the tool ready. Pin every install.
// The local Docker image (Ubuntu, Python 3.14) has no python3-venv and an externally managed
// Python, so install per user: scripts land in ~/.local/bin, which is on the sandbox PATH.
const SETUP = [
  "python3 -m pip install --user --break-system-packages --quiet 'git+https://github.com/<owner>/<repo>@<commit-sha>'",
  // System packages differ: Docker locally is Ubuntu (sudo apt-get), Vercel Sandbox is Amazon Linux (sudo dnf).
];

export const environment = DefaultSandbox.environment({
  prepare: async (sandbox) => {
    for (const command of SETUP) {
      const result = await sandbox.run({ command });
      if (result.exitCode !== 0) throw new Error(`${command}\n${result.stderr}`);
    }
  },
});

export default defineSandbox(() => environment.open());
