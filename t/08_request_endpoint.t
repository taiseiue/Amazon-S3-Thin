#!/usr/bin/env perl
use strict;
use warnings;
use Amazon::S3::Thin;
use Test::More;

my $arg = +{
    aws_access_key_id     => "dummy",
    aws_secret_access_key => "dummy",
    region => 'us-east-1',
    endpoint => 'http://localhost:9000',
};

$arg->{ua} = MockUA->new;
my $client = Amazon::S3::Thin->new($arg);

my $bucket = "tmpfoobar";
my $key =  "dir/private.txt";
my $body = "hello world";

my $res1 = $client->put_object($bucket, $key, $body);
my $res2 = $client->get_object($bucket, $key);
my $res3 = $client->head_object($bucket, $key);
my $res4 = $client->delete_object($bucket, $key);

my $req1 = $res1->request;
my $req2 = $res2->request;
my $req3 = $res3->request;
my $req4 = $res4->request;

diag "test PUT request with custom endpoint";
is $req1->method, "PUT";
is $req1->content, $body;
is $req1->uri, "http://localhost:9000/tmpfoobar/dir/private.txt";

diag "test GET request with custom endpoint";
is $req2->method, "GET";
is $req2->uri, "http://localhost:9000/tmpfoobar/dir/private.txt";

diag "test HEAD request with custom endpoint";
is $req3->method, "HEAD";
is $req3->uri, "http://localhost:9000/tmpfoobar/dir/private.txt";

diag "test DELETE request with custom endpoint";
is $req4->method, "DELETE";
is $req4->uri, "http://localhost:9000/tmpfoobar/dir/private.txt";

diag "test GET request for list_objects with custom endpoint";
my $res5 = $client->list_objects($bucket, {prefix => "12012", delimiter => "/"});
my $req5 = $res5->request;
is $req5->method, "GET";
is $req5->uri, "http://localhost:9000/tmpfoobar/?delimiter=%2F&prefix=12012";

diag "test POST for delete_multiple_objects with custom endpoint";
my $res6 = $client->delete_multiple_objects( $bucket, 'key/one.txt', 'key/two.png' );
my $req6 = $res6->request;
is $req6->method, "POST";
is $req6->uri, "http://localhost:9000/tmpfoobar/?delete=";
is $req6->header('Content-MD5'), 'pjGVehBgNtca8xN21pLCCA==';

diag "test PUT request (copy) with custom endpoint";
my $res7 = $client->copy_object($bucket, $key, $bucket, "copied.txt", {"x-amz-acl" => "public-read"});
my $req7 = $res7->request;
is $req7->method, "PUT";
is $req7->uri, "http://localhost:9000/tmpfoobar/copied.txt";
is $req7->header("x-amz-copy-source"), "tmpfoobar/dir/private.txt";
is $req7->header("x-amz-acl"), "public-read";

subtest 'endpoint with trailing slash' => sub {
    my $client2 = Amazon::S3::Thin->new({
        aws_access_key_id     => "dummy",
        aws_secret_access_key => "dummy",
        region   => 'us-east-1',
        endpoint => 'http://localhost:9000/',
        ua       => MockUA->new,
    });
    my $res = $client2->get_object($bucket, $key);
    is $res->request->uri, "http://localhost:9000/tmpfoobar/dir/private.txt",
        "trailing slash in endpoint is handled correctly";
};

subtest 'endpoint without region defaults to us-east-1' => sub {
    my $client3 = Amazon::S3::Thin->new({
        aws_access_key_id     => "dummy",
        aws_secret_access_key => "dummy",
        endpoint => 'https://minio.example.com',
        ua       => MockUA->new,
    });
    my $res = $client3->get_object($bucket, $key);
    is $res->request->uri, "https://minio.example.com/tmpfoobar/dir/private.txt",
        "endpoint works without explicit region";
};

subtest 'endpoint with custom port' => sub {
    my $client4 = Amazon::S3::Thin->new({
        aws_access_key_id     => "dummy",
        aws_secret_access_key => "dummy",
        region   => 'us-east-1',
        endpoint => 'http://192.168.1.100:9000',
        ua       => MockUA->new,
    });
    my $res = $client4->get_object($bucket, $key);
    is $res->request->uri, "http://192.168.1.100:9000/tmpfoobar/dir/private.txt",
        "endpoint with IP address and port works correctly";
};

done_testing;

package MockUA;

sub new {
    my $class = shift;
    bless {}, $class;
}

sub request {
    my $self = shift;
    my $request = shift;
    return MockResponse->new({request =>$request});
}

package MockResponse;

sub new {
    my ($class, $self) = @_;
    bless $self, $class;
}

sub request {
    my $self = shift;
    return $self->{request};
}

sub code {
    my $self = shift;
    return 200;
}

sub content {
    my $self = shift;
    return <<'XML';
<CopyObjectResult>
    <LastModified>2009-10-28T22:32:00</LastModified>
    <ETag>"9b2cf535f27731c974343645a3985328"</ETag>
<CopyObjectResult>
XML
}

;
