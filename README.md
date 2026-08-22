# Status Bar

Unified macOS menu bar monitor for Codex quota, AWS Lightsail traffic and
Yuhaiin live traffic.

## Build

```sh
cd /Users/asutorufa/Documents/Programming/status_bar
./build.sh
open build/StatusBar.app
```

## Release

Push a version tag to build a macOS app and upload it to the GitHub Release
Assets automatically:

```sh
git tag v0.1.0
git push origin v0.1.0
```

The workflow creates `StatusBar-v0.1.0.zip` and `SHA256SUMS`. It can also be
started manually from the Actions page by supplying a release tag. The current
workflow uses an ad-hoc signature; Apple Developer signing and notarization
can be added later if public distribution requires it.

The app stores non-sensitive preferences in
`~/Library/Application Support/StatusBar/settings.json` and secrets in the
macOS Keychain as one combined credential item, so saving settings requires a
single Keychain authorization; when all credential fields are empty, saving
does not touch Keychain. The menu bar value can be switched between all registered
providers from Settings. The provider protocol is intentionally independent
from the UI so future custom metrics can be added without changing the status
item or settings flow.

The bundled icon is reused from the original Codex usage utility so the merged
app keeps a familiar visual identity while the new panel uses a shared glass
surface and animated metric cards.

Codex, Lightsail and Yuhaiin each have an independent refresh timer. The
default intervals are 300 seconds, 600 seconds and 5 seconds respectively;
the values can be changed separately in Settings.

Refresh work is visibility-aware: while the panel is closed, only the provider
currently shown in the menu bar is refreshed. Opening the panel temporarily
refreshes all providers for the dashboard, and cycle mode keeps all providers
active because each one can be shown in the menu bar. Providers that are no
longer needed have their in-flight tasks cancelled.

Lightsail also queries AWS Cost Explorer for the current month's billed
Lightsail transfer. The menu bar and primary remaining value always use the
near-real-time instance metrics; billing is shown separately as a delayed
reference. Cost Explorer data is cached for 24 hours because AWS billing data
can lag by roughly a day.

Click any dashboard card to open provider-specific details. Codex includes
rate-limit windows, reset information, credits and account fields. Lightsail
includes the summary plus each instance's region, state, public IP, bundle
specification and NetworkIn/NetworkOut usage. Yuhaiin includes live rates,
cumulative totals and the management endpoint.

AWS uses native HTTPS JSON API requests signed with SigV4. It does not spawn
the AWS CLI. Credentials can be entered in Settings, supplied through
`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`, or read from the selected AWS
profile in `~/.aws/credentials`. If Region is blank, the app uses `AWS_REGION`,
`AWS_DEFAULT_REGION`, or the selected profile's `region` in `~/.aws/config`,
then falls back to `ap-northeast-1`.

The direct AWS client currently supports static credentials; AWS SSO and
`credential_process` profiles are not yet handled.
