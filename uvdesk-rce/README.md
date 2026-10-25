# UVdesk unauthenticated zero-click RCE (CVE-2024-0916 sibling regression)

Unauthenticated, zero-click remote code execution in UVdesk via the mailbox
email-attachment ingestion path. A single email with a `.php` attachment sent to
the helpdesk's public support address results in code execution on the server.
No login, no account, no victim interaction.

## What it is

UVdesk shipped a fix for CVE-2024-0916 that set `renameFile=true` on
`Localhost::uploadFile()`. The 2021 commit that introduced the original bug
flipped the same unsafe default on a second method in the same file,
`uploadEmailAttachment()`, and the fix never touched it. The interface declares
the safe default (`true`), but PHP does not enforce interface defaults on the
implementing class, so the unsafe `false` is what runs.

`TicketService::saveThreadEmailAttachments()` calls `uploadEmailAttachment()`
with no rename argument, so every inbound email attachment inherits the unsafe
default. This branch also skips the extension and MIME validation used
everywhere else. The attacker's file is written to
`public/assets/threads/<id>/<filename>` with its original name and extension,
inside the web root, and served and executed directly.

## Impact

- Unauthenticated. No credentials.
- Zero-click. The attacker sends one email. The victim does nothing.
- Remote. The public support mailbox is the attack surface.
- Code execution as the web service account (`uid=1001(uvdesk)` on a standard
  deploy), which can read the mailbox IMAP/SMTP credentials, the app secret,
  the database, and every customer ticket, and pivot inside the network.

## Discovery

Found by Project Apex, fully autonomously, on 2026-08-12. Verified end to end
against the real application (MySQL, IMAP, SMTP) and against the extracted
vulnerable class. Still unpatched upstream at time of writing.

## Proof of concept

Two harnesses, both run the real unmodified `Localhost.php` from UVdesk
`core-framework`.

`poc-minimal/` is a one-command Docker proof:

```
cd poc-minimal && ./run.sh
```

`poc/` is the demo used for the writeup, three terminals:

```
cd poc
nc -l 4444        # terminal 1, catches the shell
./start.sh        # terminal 2, victim helpdesk on :8930
./demo.sh         # terminal 3, fires the exploit
```

## Fix and mitigation

Set `uploadEmailAttachment()`'s default to `true`, and add attachment
validation to the email ingestion branch of `TicketService::createThread()`.
Operators who cannot patch should block execution of `.php` under
`public/assets/` at the web server, disable the mailbox refresh cron if unused,
and strip executable attachments at the mail gateway.
