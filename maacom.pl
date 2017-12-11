#!@perl@

package aConfig;

use strict;
use warnings;

sub new {
    my ($class, $file) = @_;
    my $self = {
        file => $file
    };
    bless $self, $class;
    $self;
}

sub file {
    my ($self, $name) = @_;
    return $self->{'file'} unless $name;
    $self->{'file'} = $name;
    $self;
}

sub read {
    my $self = shift;
    return undef unless -r $self->file;
    open my $fh, '<', $self->file;
    my %res;
    while (my $line = readline $fh) {
        chomp $line;
        $line =~ s/^\s+//g;

        next if $line =~ /^#/;
        next if $line =~ /^;/;
        next unless $line =~ /[=:]/;

        $line =~ s/[\"\']//g;
        my ($key, $rawvalue) = split(/==|=>|[=:]/, $line);
        next unless $rawvalue and $key;

        my ($value, $comment) = split(/[#;,]/, $rawvalue);

        $key =~ s/^\s+|\s+$//g;
        $value =~ s/^\s+|\s+$//g;

        $res{$key} = $value;
    }
    close $fh;
    \%res;
}

1;

#----------
#--- DB ---
#----------

package aDB;

use strict;
use warnings;
use DBI;
use DBD::Pg;

sub new {
    my ($class, %args) = @_;
    my $self = {
        hostname => $args{hostname} || '',
        username => $args{username} || '',
        password => $args{password} || '',
        database => $args{database} || '',
        engine => $args{engine} || 'SQLite',
        error => ''
    };
    bless $self, $class;
    return $self;
}

sub username {
    my ($self, $username) = @_;
    return $self->{username} unless $username;
    $self->{username} = $username;
    $self;
}

sub password {
    my ($self, $password) = @_;
    return $self->{password} unless $password;
    $self->{password} = $password;
    $self;
}

sub hostname {
    my ($self, $hostname) = @_;
    return $self->{hostname} unless $hostname;
    $self->{hostname} = $hostname;
    $self;
}

sub database {
    my ($self, $database) = @_;
    return $self->{database} unless $database;
    $self->{database} = $database;
    $self;
}

sub error {
    my ($self, $error) = @_;
    return $self->{error} unless $error;
    $self->{error} = $error;
    $self;
}

sub engine {
    my ($self, $engine) = @_;
    return $self->{engine} unless $engine;
    $self->{engine} = $engine;
    $self;
}

sub exec {
    my ($self, $query) = @_;
    return undef unless $query;

    my $dsn = 'dbi:'.$self->engine.
                ':dbname='.$self->database.
                ';host='.$self->hostname;
    my $dbi;
    eval {
        $dbi = DBI->connect($dsn, $self->username, $self->password, {
            RaiseError => 1,
            PrintError => 0,
            AutoCommit => 1
        });
    };
    $self->error($@);
    return undef if $@;

    my $sth;
#    eval {
        $sth = $dbi->prepare($query);
#    };
    $self->error($@);
    return undef if $@;

    my $rows = $sth->execute;
    my @list;

    while (my $row = $sth->fetchrow_hashref) {
        push @list, $row;
    }
    $sth->finish;
    $dbi->disconnect;
    \@list;
}

sub exec1 {
    my ($self, $query) = @_;
    return undef unless $query;

    my $dsn = 'dbi:'.$self->engine.
                ':dbname='.$self->database.
                ';host='.$self->hostname;
    my $dbi;
#    eval {
        $dbi = DBI->connect($dsn, $self->username, $self->password, {
            RaiseError => 1,
            PrintError => 0,
            AutoCommit => 1
        });
#    };
    $self->error($@);
    return undef if $@;

    my $sth;
    eval {
        $sth = $dbi->prepare($query);
    };
    $self->error($@);
    return undef if $@;

    my $rows = $sth->execute;
    my $row = $sth->fetchrow_hashref;

    $sth->finish;
    $dbi->disconnect;
    $row;
}

sub do {
    my ($self, $query) = @_;
    return undef unless $query;
    my $dsn = 'dbi:'.$self->engine.
                ':dbname='.$self->database.
                ';host='.$self->hostname;
    my $dbi;
    eval {
        $dbi = DBI->connect($dsn, $self->username, $self->password, {
            RaiseError => 1,
            PrintError => 0,
            AutoCommit => 1
        });
    };
    $self->error($@);
    return undef if $@;
    my $rows;
    eval {
        $rows = $dbi->do($query);
    };
    $self->error($@);
    return undef if $@;

    $dbi->disconnect;
    $rows*1;
}

1;

#------------
#--- USER ---
#------------

package aUser;

use strict;
use warnings;
use Digest::SHA qw(sha512_base64);

sub new {
    my ($class, $db) = @_;
    my $self = { db => $db};
    bless $self, $class;
    return $self;
}

sub db {
    my ($self, $db) = @_;
    return $self->{db} unless $db;
    $self->{db} = $db;
    $self;
}

# --- DOMAIN ---

sub domain_exist {
    my ($self, $name) = @_;
    return undef unless $name;
    my $res = $self->db->exec1("select id from domains where name = '$name' order by id limit 1");
    $res->{id};
}

sub domain_profile {
    my ($self, $id) = @_;
    return undef unless $id;
    my $row = $self->db->exec1("select * from domains where domains.id = $id limit 1");
    $row;
}

sub domain_user_count {
    my ($self, $id) = @_;
    return undef unless $id;
    my $row = $self->db->exec1("select count(users.name) as count
                                from domains, users 
                                where domains.id = users.domain_id and domains.id = $id
                                limit 1");
    $row->{count} || 0;
}

sub domain_alias_count {
    my ($self, $id) = @_;
    return undef unless $id;
    my $row = $self->db->exec1("select count(aliases.name) as count 
                                from domains, aliases 
                                where domains.id = aliases.domain_id and domains.id = $id
                                limit 1");
    $row->{count} || 0;
}

sub domain_nextid {
    my $self = shift;
    my $res = $self->db->exec1("select id from domains order by id desc limit 1");
    my $id = $res->{id} || 0;
    $id += 1;
}

sub domain_add {
    my ($self, $name) = @_;
    return undef unless $name;
    return undef if $self->domain_exist($name);
    my $next_id = $self->domain_nextid;
    $self->db->do("insert into domains (id, name) values ($next_id, '$name')");
    $self->domain_exist($name);
}

sub domain_list {
    my $self = shift;
    $self->db->exec("select * from domains order by id");
}

sub domain_update {
    my ($self, $id, %args) = @_;
    return undef unless $id;
    my $prof = $self->domain_profile($id);
    return undef unless $prof;

    my $name = $args{name} || $prof->{name};
    my $quota = $args{quota} || $prof->{quota};
    my $size = $prof->{size};
    $size = $args{size} if $args{size} >= 0;

    $self->db->do("update domains set name = '$name', size = $size, quota = $quota where id = $id");
    my $res = $self->domain_profile($id);
    return undef unless $res->{name} eq $name;
    $id;
}


sub domain_delete {
    my ($self, $id) = @_;
    return undef unless $id;
#    return $id unless $self->domain_profile($id);
    $self->db->do("delete from domains where id = $id");
    $self->db->do("delete from users where domain_id = $id");
    $self->db->do("delete from aliases where domain_id = $id");
    return undef if $self->domain_profile($id);
    $id;
}

# --- ALAIS ---

sub alias_exist {
    my ($self, $name, $domain_id) = @_;
    return undef unless $name;
    return undef unless $domain_id;
    my $res = $self->db->exec1("select a.id as id from domains d, aliases a
                                where a.name = '$name' and a.domain_id = $domain_id
                                limit 1");
    $res->{id};
}

sub alias_profile {
    my ($self, $id) = @_;
    return undef unless $id;
    $self->db->exec1("select a.id as id,
                            a.name as name,
                            a.name || '\@' || d.name as address,
                            a.domain_id as domain_id,
                            d.name as domain_name,
                            a.list as list
                        from aliases a, domains d
                        where a.domain_id = d.id and a.id = $id
                        limit 1");
}

sub alias_list {
    my ($self, $domain_id) = @_;
    my $and = "and a.domain_id = $domain_id" if $domain_id;
    $self->db->exec("select a.id as id,
                            a.name as name,
                            a.name || '\@' || d.name as address,
                            a.domain_id as domain_id,
                            d.name as domain_name,
                            a.list as list
                        from aliases a, domains d
                        where a.domain_id = d.id $and
                        order by a.id, d.id"
    );
}

sub alias_nextid {
    my $self = shift;
    my $res = $self->db->exec1('select id from aliases order by id desc limit 1');
    my $id = $res->{id} || 0;
    $id += 1;
}

sub alias_add {
    my ($self, $name, $list, $domain_id) = @_;
    return undef unless $name;
    return undef unless $list;
    return undef unless $domain_id;

    return undef if $self->alias_exist($name, $domain_id);
    return undef unless $self->domain_profile($domain_id);
    my $next_id = $self->alias_nextid;
    $self->db->do("insert into aliases (id, name, list, domain_id) 
                    values ($next_id, '$name', '$list', $domain_id)");
    $self->alias_exist($name, $domain_id);
}

sub alias_delete {
    my ($self, $id) = @_;
    return undef unless $id;
    return $id unless $self->alias_profile($id);
    $self->db->do("delete from aliases where id = $id");
    return undef if $self->alias_profile($id);
    $id;
}

sub alias_update {
    my ($self, $id, %args) = @_;
    my $prof = $self->alias_profile($id);
    return undef unless $prof;

    my $name = $args{name} || $prof->{name};
    my $list = $args{list} || $prof->{list};

    $self->db->do("update aliases set name = '$name', list = '$list'
                    where id = $id");
    my $res = $self->alias_profile($id);
    return undef unless $res->{name} eq $name;
    return undef unless $res->{list} eq $list;
    $id ;
}

# --- USER ---

sub user_exist {
    my ($self, $name, $domain_id) = @_;
    return undef unless $name;
    return undef unless $domain_id;
    my $res = $self->db->exec1("select u.id as id from domains d, users u
                                where u.name = '$name' and u.domain_id = $domain_id
                                limit 1");
    $res->{id};
}

sub user_profile {
    my ($self, $id) = @_;
    return undef unless $id;
    $self->db->exec1("select u.id as id,
                                    u.name as name,
                                    u.name || '\@' || d.name as address,
                                    u.domain_id as domain_id,
                                    d.name as domain_name,
                                    u.password as password,
                                    u.hash as hash,
                                    u.size as size,
                                    u.quota as quota
                        from users u, domains d
                        where u.domain_id = d.id and u.id = $id
                        limit 1");
}

sub user_list {
    my ($self, $domain_id) = @_;
    my $and = "and u.domain_id = $domain_id" if $domain_id;
    $self->db->exec("select u.id as id,
                            u.name as name,
                            u.name || '\@' || d.name as address,
                            u.domain_id as domain_id,
                            d.name as domain_name,
                            u.password as password,
                            u.size as size,
                            u.quota as quota
                        from users u, domains d
                        where u.domain_id = d.id $and
                        order by u.name, d.name"
    );
}

sub user_nextid {
    my $self = shift;
    my $res = $self->db->exec1('select id from users order by id desc limit 1');
    my $id = $res->{id} || 0;
    $id += 1;
}

sub user_add {
    my ($self, $name, $password, $domain_id) = @_;
    return undef unless $name;
    return undef unless $password;
    return undef unless $domain_id;

    return undef if $self->user_exist($name, $domain_id);
    return undef unless $self->domain_profile($domain_id);
    my $next_id = $self->user_nextid;
    my $salt = substr(sha512_base64(sprintf("%X", rand(2**31-1))), 4, 16);
    my $hash = crypt($password,'$6$'.$salt.'$');

    $self->db->do("insert into users (id, name, password, domain_id, hash) 
                    values ($next_id, '$name', '$password', $domain_id, '$hash')");
    $self->user_exist($name, $domain_id);
}

sub user_update {
    my ($self, $id, %args) = @_;
    my $prof = $self->user_profile($id);
    return undef unless $prof;

    my $name = $args{name} || $prof->{name};
    my $password = $args{password} || $prof->{password};
    my $hash = $prof->{hash};
    if ($args{password}) {
        my $salt = substr(sha512_base64(sprintf("%X", rand(2**31-1))), 4, 16);
        $hash = crypt($password,'$6$'.$salt.'$');
    }

    my $quota = $args{quota} || $prof->{quota};
    my $size = $prof->{size};
    $size = $args{size} if $args{size} >= 0;
    $size ||= 0;

    $self->db->do("update users set name = '$name',
                                password = '$password',
                                size = $size,
                                quota = $quota,
                                hash = '$hash'
                            where id = $id");
    my $res = $self->user_profile($id);
    return undef unless $res->{name} eq $name;
    return undef unless $res->{password} eq $password;
    $id ;
}

sub user_delete {
    my ($self, $id) = @_;
    return undef unless $id;
#    return $id unless $self->user_profile($id);
    $self->db->do("delete from users where id = $id");
    return undef if $self->user_profile($id);
    $id;
}


# --- FORWARD ---

sub forwarded_exist {
    my ($self, $name) = @_;
    return undef unless $name;
    my $res = $self->db->exec1("select id from forwarded where name = '$name' order by id limit 1");
    $res->{id};
}

sub forwarded_profile {
    my ($self, $id) = @_;
    return undef unless $id;
    my $row = $self->db->exec1("select * from forwarded where forwarded.id = $id limit 1");
    $row;
}

sub forwarded_nextid {
    my $self = shift;
    my $res = $self->db->exec1("select id from forwarded order by id desc limit 1");
    my $id = $res->{id} || 0;
    $id += 1;
}

sub forwarded_add {
    my ($self, $name) = @_;
    return undef unless $name;
    return undef if $self->forwarded_exist($name);
    my $next_id = $self->forwarded_nextid;
    $self->db->do("insert into forwarded (id, name) values ($next_id, '$name')");
    $self->forwarded_exist($name);
}

sub forwarded_list {
    my $self = shift;
    $self->db->exec("select * from forwarded order by id");
}

sub forwarded_update {
    my ($self, $id, %args) = @_;
    return undef unless $id;
    my $prof = $self->forwarded_profile($id);
    return undef unless $prof;

    my $name = $args{name} || $prof->{name};

    $self->db->do("update forwarded set name = '$name' where id = $id");
    my $res = $self->forwarded_profile($id);
    return undef unless $res->{name} eq $name;
    $id;
}


sub forwarded_delete {
    my ($self, $id) = @_;
    return undef unless $id;
#    return $id unless $self->forwarded_profile($id);
    $self->db->do("delete from forwarded where id = $id");
    return undef if $self->forwarded_profile($id);
    $id;
}


# --- UNWANTED ---

sub unwanted_exist {
    my ($self, $name) = @_;
    return undef unless $name;
    my $res = $self->db->exec1("select id from unwanted where name = '$name' order by id limit 1");
    $res->{id};
}

sub unwanted_profile {
    my ($self, $id) = @_;
    return undef unless $id;
    my $row = $self->db->exec1("select * from unwanted where unwanted.id = $id limit 1");
    $row;
}

sub unwanted_nextid {
    my $self = shift;
    my $res = $self->db->exec1("select id from unwanted order by id desc limit 1");
    my $id = $res->{id} || 0;
    $id += 1;
}

sub unwanted_add {
    my ($self, $name) = @_;
    return undef unless $name;
    return undef if $self->unwanted_exist($name);
    my $next_id = $self->unwanted_nextid;
    $self->db->do("insert into unwanted (id, name) values ($next_id, '$name')");
    $self->unwanted_exist($name);
}

sub unwanted_list {
    my $self = shift;
    $self->db->exec("select * from unwanted order by id");
}

sub unwanted_update {
    my ($self, $id, %args) = @_;
    return undef unless $id;
    my $prof = $self->unwanted_profile($id);
    return undef unless $prof;

    my $name = $args{name} || $prof->{name};

    $self->db->do("update unwanted set name = '$name' where id = $id");
    my $res = $self->unwanted_profile($id);
    return undef unless $res->{name} eq $name;
    $id;
}


sub unwanted_delete {
    my ($self, $id) = @_;
    return undef unless $id;
#    return $id unless $self->unwanted_profile($id);
    $self->db->do("delete from unwanted where id = $id");
    return undef if $self->unwanted_profile($id);
    $id;
}

# --- TRUSTED ---

sub trusted_exist {
    my ($self, $name) = @_;
    return undef unless $name;
    my $res = $self->db->exec1("select id from trusted where name = '$name' order by id limit 1");
    $res->{id};
}

sub trusted_profile {
    my ($self, $id) = @_;
    return undef unless $id;
    my $row = $self->db->exec1("select * from trusted where trusted.id = $id limit 1");
    $row;
}

sub trusted_nextid {
    my $self = shift;
    my $res = $self->db->exec1("select id from trusted order by id desc limit 1");
    my $id = $res->{id} || 0;
    $id += 1;
}

sub trusted_add {
    my ($self, $name) = @_;
    return undef unless $name;
    return undef if $self->trusted_exist($name);
    my $next_id = $self->trusted_nextid;
    $self->db->do("insert into trusted (id, name) values ($next_id, '$name')");
    $self->trusted_exist($name);
}

sub trusted_list {
    my $self = shift;
    $self->db->exec("select * from trusted order by id");
}

sub trusted_update {
    my ($self, $id, %args) = @_;
    return undef unless $id;
    my $prof = $self->trusted_profile($id);
    return undef unless $prof;

    my $name = $args{name} || $prof->{name};

    $self->db->do("update trusted set name = '$name' where id = $id");
    my $res = $self->trusted_profile($id);
    return undef unless $res->{name} eq $name;
    $id;
}


sub trusted_delete {
    my ($self, $id) = @_;
    return undef unless $id;
#    return $id unless $self->trusted_profile($id);
    $self->db->do("delete from trusted where id = $id");
    return undef if $self->trusted_profile($id);
    $id;
}




1;

#--------------
#--- DAEMON ---
#--------------

package Daemon;

use strict;
use warnings;
use POSIX qw(getpid setuid setgid geteuid getegid);
use Cwd qw(cwd getcwd chdir);
use Mojo::Util qw(dumper);

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    return $self;
}

sub fork {
    my $self = shift;
    my $pid = fork;
    if ($pid > 0) {
        exit;
    }
    chdir("/");
    open(my $stdout, '>&', STDOUT); 
    open(my $stderr, '>&', STDERR);
    open(STDOUT, '>>', '/dev/null');
    open(STDERR, '>>', '/dev/null');
    getpid;
}

1;

#-------------
#--- TAIL ----
#-------------

package Tail;

use strict;
use warnings;

sub new {
    my ($class, $file) = @_;
    my $self = {
        file => $file,
        pos => 0
    };
    bless $self, $class;
    return $self;
}

sub file {
    my ($self, $name) = @_;
    return $self->{'file'} unless $name;
    $self->{'file'} = $name;
}

sub pos {
    my ($self, $pos) = @_;
    return $self->{'pos'} unless $pos;
    $self->{'pos'} = $pos;
}

sub first {
    my $self = shift;
    open my $fh, '<', $self->file;
    seek $fh, -2000, 2;
    readline $fh;
    my @res;
    while (my $line = readline $fh) {
        push @res, $line;
    }
    $self->pos(tell $fh);
    \@res;
}

sub last {
    my $self = shift;
    open my $fh, '<', $self->file;
    seek $fh, $self->pos, 0;
    my @res;
    while (my $line = readline $fh) {
        push @res, $line;
    }
    $self->pos(tell $fh);
    \@res;
}

1;

#--------------------
#--- CONTROLLER 1 ---
#--------------------

package MAM::Controller;

use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Util qw(dumper);
use Mojo::JSON qw(decode_json encode_json);

use Apache::Htpasswd;

# --- AUTH ---

sub pwfile {
    my ($self, $pwfile) = @_;
    return $self->app->config('pwfile') unless $pwfile;
    $self->app->config(pwfile => $pwfile);
}

sub log {
    my ($self, $log) = @_;
    return $self->app->log unless $log;
    $self->app->log = $log;
}

sub ucheck {
    my ($self, $username, $password) = @_;
    return undef unless $password;
    return undef unless $username;
    my $pwfile = $self->pwfile or return undef;
    my $res = undef;
    eval {
        my $ht = Apache::Htpasswd->new({ passwdFile => $pwfile, ReadOnly => 1 });
        $res = $ht->htCheckPassword($username, $password);
    };
    $res;
}

sub login {
    my $self = shift;
    return $self->redirect_to('/') if $self->session('username');

    my $username = $self->req->param('username') || undef;
    my $password = $self->req->param('password') || undef;

    return $self->render(template => 'login') unless $username and $password;

    if ($self->ucheck($username, $password)) {
        $self->session(username => $username);
        return $self->redirect_to('/');
    }
    $self->render(template => 'login');
}

sub logout {
    my $self = shift;
    $self->session(expires => 1);
    $self->redirect_to('/');
}

# --- HELLO ---

sub hello {
    my $self = shift;
    $self->render(template => 'hello');
}

# --- DOMAIN ---

sub domain_list {
    my $self = shift;
    $self->render(template => 'domain-list');
}
sub domain_add_form {
    my $self = shift;
    $self->render(template => 'domain-add-form');
}
sub domain_add_handler {
    my $self = shift;
    $self->render(template => 'domain-add-handler');
}
sub domain_update_form {
    my $self = shift; 
    $self->render(template => 'domain-update-form');
}

sub domain_update_handler {
    my $self = shift;
    $self->render(template => 'domain-update-handler');
}

sub domain_delete_form {
    my $self = shift;
    $self->render(template => 'domain-delete-form');
}

sub domain_delete_handler {
    my $self = shift;
    $self->render(template => 'domain-delete-handler');
}

# --- USER ---

sub user_list {
    my $self = shift;
    $self->render(template => 'user-list');
}

sub user_add_form {
    my $self = shift;
    $self->render(template => 'user-add-form');
}
sub user_add_handler {
    my $self = shift;
    $self->render(template => 'user-add-handler');
}

sub user_delete_form {
    my $self = shift;
    $self->render(template => 'user-delete-form');
}
sub user_delete_handler {
    my $self = shift;
    $self->render(template => 'user-delete-handler');
}

sub user_update_form {
    my $self = shift;
    $self->render(template => 'user-update-form');
}

sub user_update_handler {
    my $self = shift;
    $self->render(template => 'user-update-handler');
}

sub user_rename_form {
    my $self = shift;
    $self->render(template => 'user-rename-form');
}

sub user_rename_handler {
    my $self = shift;
    $self->render(template => 'user-rename-handler');
}

# --- ALIAS ---

sub alias_list {
    my $self = shift;
    $self->render(template => 'alias-list');
}

sub alias_add_form {
    my $self = shift;
    $self->render(template => 'alias-add-form');
}
sub alias_add_handler {
    my $self = shift;
    $self->render(template => 'alias-add-handler');
}

sub alias_delete_form {
    my $self = shift;
    $self->render(template => 'alias-delete-form');
}
sub alias_delete_handler {
    my $self = shift;
    $self->render(template => 'alias-delete-handler');
}

sub alias_update_form {
    my $self = shift;
    $self->render(template => 'alias-update-form');
}

sub alias_update_handler {
    my $self = shift;
    $self->render(template => 'alias-update-handler');
}


sub alias_rename_form {
    my $self = shift;
    $self->render(template => 'alias-rename-form');
}

sub alias_rename_handler {
    my $self = shift;
    $self->render(template => 'alias-rename-handler');
}

# --- TAIL ---

sub mxlog {
    my $self = shift;
    $self->render(template => 'mxlog');
}

# --- FORWARD ---

sub forwarded_list {
    my $self = shift;
    $self->render(template => 'forwarded-list');
}
sub forwarded_add_form {
    my $self = shift;
    $self->render(template => 'forwarded-add-form');
}
sub forwarded_add_handler {
    my $self = shift;
    $self->render(template => 'forwarded-add-handler');
}
sub forwarded_update_form {
    my $self = shift; 
    $self->render(template => 'forwarded-update-form');
}

sub forwarded_update_handler {
    my $self = shift;
    $self->render(template => 'forwarded-update-handler');
}

sub forwarded_delete_form {
    my $self = shift;
    $self->render(template => 'forwarded-delete-form');
}

sub forwarded_delete_handler {
    my $self = shift;
    $self->render(template => 'forwarded-delete-handler');
}

# --- UNWANTED ---

sub unwanted_list {
    my $self = shift;
    $self->render(template => 'unwanted-list');
}
sub unwanted_add_form {
    my $self = shift;
    $self->render(template => 'unwanted-add-form');
}
sub unwanted_add_handler {
    my $self = shift;
    $self->render(template => 'unwanted-add-handler');
}
sub unwanted_update_form {
    my $self = shift; 
    $self->render(template => 'unwanted-update-form');
}

sub unwanted_update_handler {
    my $self = shift;
    $self->render(template => 'unwanted-update-handler');
}

sub unwanted_delete_form {
    my $self = shift;
    $self->render(template => 'unwanted-delete-form');
}

sub unwanted_delete_handler {
    my $self = shift;
    $self->render(template => 'unwanted-delete-handler');
}

# --- TRUSTED ---

sub trusted_list {
    my $self = shift;
    $self->render(template => 'trusted-list');
}
sub trusted_add_form {
    my $self = shift;
    $self->render(template => 'trusted-add-form');
}
sub trusted_add_handler {
    my $self = shift;
    $self->render(template => 'trusted-add-handler');
}
sub trusted_update_form {
    my $self = shift; 
    $self->render(template => 'trusted-update-form');
}

sub trusted_update_handler {
    my $self = shift;
    $self->render(template => 'trusted-update-handler');
}

sub trusted_delete_form {
    my $self = shift;
    $self->render(template => 'trusted-delete-form');
}

sub trusted_delete_handler {
    my $self = shift;
    $self->render(template => 'trusted-delete-handler');
}

1;

#-----------
#--- APP ---
#-----------

package MAM;

use strict;
use warnings;
use Mojo::Base 'Mojolicious';

sub startup {
    my $self = shift;
}

1;

#------------
#--- MAIN ---
#------------

use strict;
use warnings;
use Mojo::Server::Prefork;
use Mojo::Util qw(dumper);
use File::stat;

my $appname = 'maacom';

my $server = Mojo::Server::Prefork->new;
my $app = $server->build_app('MAM');
$app = $app->controller_class('MAM::Controller');

$app->secrets(['6d578e43ba88260e0375a1a35fd7954b']);

$app->static->paths(['@app_libdir@/public']);
$app->renderer->paths(['@app_libdir@/templs']);

$app->config(conffile => '@app_confdir@/maacom.conf');
$app->config(pwfile => '@app_confdir@/maacom.pw');
$app->config(logfile => '@app_logdir@/maacom.log');
$app->config(loglevel => 'info');
$app->config(pidfile => '@app_rundir@/maacom.pid');
$app->config(crtfile => '@app_confdir@/maacom.crt');
$app->config(keyfile => '@app_confdir@/maacom.key');

$app->config(listenaddr4 => '0.0.0.0');
$app->config(listenaddr6 => '[::]');
$app->config(listenport => '8082');

$app->config(mxlog => '/var/log/mail.log');
$app->config(maildir => '/var/vmail');

$app->config(dbname => '@app_datadir@/mail.db');
$app->config(dbhost => '');
$app->config(dblogin => '');
$app->config(dbpassword => '');
$app->config(dbengine => 'sqlite3');

if (-r $app->config('conffile')) {
    $app->log->debug("Load configuration from ".$app->config('conffile'));
#    $app->plugin('JSONConfig', { file => $app->config('conffile') });
    my $c = aConfig->new($app->config('conffile'));
    my $hash = $c->read;
    foreach my $key (keys %$hash) {
        $app->config($key => $hash->{$key});
    }
}

#---------------
#--- HELPERS ---
#---------------
$app->helper(
    tail => sub {
        state $tail = Tail->new($app->config('mxlog'));
});

$app->helper(
    db => sub {
        my $engine = 'SQLite' if $app->config('dbengine') =~ /sqlite/i;
        $engine = 'Pg' if $app->config('dbengine') =~ /postgres/i;
        state $db = aDB->new(
            database => $app->config('dbname'),
            hostname => $app->config('dbhost'),
            username => $app->config('dblogin'),
            password => $app->config('dbpassword'),
            engine => $engine
        );
});

$app->helper(
    user => sub {
        state $user = aUser->new($app->db); 
});

$app->helper('reply.not_found' => sub {
        my $c = shift; 
        return $c->redirect_to('/login') unless $c->session('username'); 
        $c->render(template => 'not_found.production');
});


#--------------
#--- ROUTES ---
#--------------

my $r = $app->routes;

$r->add_condition(
    auth => sub {
        my ($route, $c) = @_;
        $c->session('username');
    }
);

$r->any('/login')->to('controller#login');
$r->any('/logout')->over('auth')->to('controller#logout');

$r->any('/')->over('auth')->to('controller#domain_list' );
$r->any('/hello')->over('auth')->to('controller#hello');

$r->any('/domain/list')->over('auth')->to('controller#domain_list' );
$r->any('/domain/add/form')->over('auth')->to('controller#domain_add_form' );
$r->any('/domain/add/handler')->over('auth')->to('controller#domain_add_handler' );
$r->any('/domain/update/form')->over('auth')->to('controller#domain_update_form' );
$r->any('/domain/update/handler')->over('auth')->to('controller#domain_update_handler' );
$r->any('/domain/delete/form')->over('auth')->to('controller#domain_delete_form' );
$r->any('/domain/delete/handler')->over('auth')->to('controller#domain_delete_handler' );

$r->any('/user/list')->over('auth')->to('controller#user_list' );
$r->any('/user/add/form')->over('auth')->to('controller#user_add_form' );
$r->any('/user/add/handler')->over('auth')->to('controller#user_add_handler' );
$r->any('/user/update/form')->over('auth')->to('controller#user_update_form' );
$r->any('/user/update/handler')->over('auth')->to('controller#user_update_handler' );
$r->any('/user/delete/form')->over('auth')->to('controller#user_delete_form' );
$r->any('/user/delete/handler')->over('auth')->to('controller#user_delete_handler' );
$r->any('/user/rename/form')->over('auth')->to('controller#user_rename_form' );
$r->any('/user/rename/handler')->over('auth')->to('controller#user_rename_handler' );

$r->any('/alias/list')->over('auth')->to('controller#alias_list' );
$r->any('/alias/add/form')->over('auth')->to('controller#alias_add_form' );
$r->any('/alias/add/handler')->over('auth')->to('controller#alias_add_handler' );
$r->any('/alias/update/form')->over('auth')->to('controller#alias_update_form' );
$r->any('/alias/update/handler')->over('auth')->to('controller#alias_update_handler' );
$r->any('/alias/delete/form')->over('auth')->to('controller#alias_delete_form' );
$r->any('/alias/delete/handler')->over('auth')->to('controller#alias_delete_handler' );
$r->any('/alias/rename/form')->over('auth')->to('controller#alias_rename_form' );
$r->any('/alias/rename/handler')->over('auth')->to('controller#alias_rename_handler' );

$r->any('/mxlog')->over('auth')->to('controller#mxlog' );

$r->any('/forwarded/list')->over('auth')->to('controller#forwarded_list' );
$r->any('/forwarded/add/form')->over('auth')->to('controller#forwarded_add_form' );
$r->any('/forwarded/add/handler')->over('auth')->to('controller#forwarded_add_handler' );
$r->any('/forwarded/update/form')->over('auth')->to('controller#forwarded_update_form' );
$r->any('/forwarded/update/handler')->over('auth')->to('controller#forwarded_update_handler' );
$r->any('/forwarded/delete/form')->over('auth')->to('controller#forwarded_delete_form' );
$r->any('/forwarded/delete/handler')->over('auth')->to('controller#forwarded_delete_handler' );

$r->any('/unwanted/list')->over('auth')->to('controller#unwanted_list' );
$r->any('/unwanted/add/form')->over('auth')->to('controller#unwanted_add_form' );
$r->any('/unwanted/add/handler')->over('auth')->to('controller#unwanted_add_handler' );
$r->any('/unwanted/update/form')->over('auth')->to('controller#unwanted_update_form' );
$r->any('/unwanted/update/handler')->over('auth')->to('controller#unwanted_update_handler' );
$r->any('/unwanted/delete/form')->over('auth')->to('controller#unwanted_delete_form' );
$r->any('/unwanted/delete/handler')->over('auth')->to('controller#unwanted_delete_handler' );


$r->any('/trusted/list')->over('auth')->to('controller#trusted_list' );
$r->any('/trusted/add/form')->over('auth')->to('controller#trusted_add_form' );
$r->any('/trusted/add/handler')->over('auth')->to('controller#trusted_add_handler' );
$r->any('/trusted/update/form')->over('auth')->to('controller#trusted_update_form' );
$r->any('/trusted/update/handler')->over('auth')->to('controller#trusted_update_handler' );
$r->any('/trusted/delete/form')->over('auth')->to('controller#trusted_delete_form' );
$r->any('/trusted/delete/handler')->over('auth')->to('controller#trusted_delete_handler' );


#----------------
#--- LISTENER ---
#----------------

my $tls = '?';
$tls .= 'cert='.$app->config('crtfile');
$tls .= '&key='.$app->config('keyfile');

my $listen4;
if ($app->config('listenaddr4')) {
    $listen4 = "https://";
    $listen4 .= $app->config('listenaddr4').':'.$app->config('listenport');
    $listen4 .= $tls;
}

my $listen6;
if ($app->config('listenaddr6')) {
    $listen6 = "https://";
    $listen6 .= $app->config('listenaddr6').':'.$app->config('listenport');
    $listen6 .= $tls;
}

my @listen;
push @listen, $listen4 if $listen4;
push @listen, $listen6 if $listen6;

$server->listen(\@listen);
$server->heartbeat_interval(3);
$server->heartbeat_timeout(60);

my $d = Daemon->new;
$d->fork;

$server->pid_file($app->config('pidfile'));

$app->log(Mojo::Log->new( 
                path => $app->config('logfile'),
                level => $app->config('loglevel')
));

$app->hook(before_dispatch => sub {
        my $c = shift;

        my $remote_address = $c->tx->remote_address;
        my $method = $c->req->method;

        my $base = $c->req->url->base->to_string;
        my $path = $c->req->url->path->to_string;
        my $loglevel = $c->app->log->level;
        my $url = $c->req->url->to_abs->to_string;

        my $username  = $c->session('username') || 'undef';

        unless ($loglevel eq 'debug') {
            #$c->app->log->info("$remote_address $method $base$path $username");
            $c->app->log->info("$remote_address $method $url $username");
        }
        if ($loglevel eq 'debug') {
            $c->app->log->debug("$remote_address $method $url $username");
        }
});


# Set signal handler
local $SIG{HUP} = sub {
    $app->log->info('Catch HUP signal'); 
    $app->log(Mojo::Log->new(
                    path => $app->config('logfile'),
                    level => $app->config('loglevel')
    ));
};


sub du {
    my ($subj, $maxdeep, $deep) = @_;
    $maxdeep ||= 10;
    $deep ||= 0;
    my $stat = stat($subj);
    return int($stat->size/1024) if -f $subj;

    $deep += 1;
    return 0 if $deep > $maxdeep;
    opendir(my $dir, $subj) or return 0;
    my $res ||= 0;
    foreach my $rec (readdir $dir) {
        next if $rec =~ /^.$/;
        next if $rec =~ /^..$/;
        $res = $res + du("$subj/$rec", $maxdeep, $deep);
    }
    $res;
}

my $sub = Mojo::IOLoop::Subprocess->new;
$sub->run(
    sub {
        my $subproc = shift;
        my $loop = Mojo::IOLoop->singleton;
        my $id = $loop->recurring(
            300 => sub {
                my $total = 0;
                foreach my $domain (@{$app->user->domain_list}) {
                    my $dir = $app->config('maildir');
                    my $domain_id = $domain->{id};
                    my $domain = $domain->{name};
                    my $size = du("$dir/$domain") || 0;
                    $app->user->domain_update($domain_id, size => $size);
                    $total += $size;
                }
                foreach my $user (@{$app->user->user_list}) {
                    my $dir = $app->config('maildir');
                    my $user_id = $user->{id};
                    my $user_name = $user->{name};
                    my $domain = $user->{domain_name};
                    my $size = du("$dir/$domain/$user_name") || 0;
                    $app->user->user_update($user_id, size => $size);
                }
                $app->log->info("Disc usage has been wrote, total $total");
            }
        );
        $loop->start unless $loop->is_running;
        1;
    },
    sub {
        my ($subprocess, $err, @results) = @_;
        $app->log->info('Exit subprocess');
        1;
    }
);

my $pid = $sub->pid;
$app->log->info("Subrocess $pid start ");

$server->on(
    finish => sub {
        my ($prefork, $graceful) = @_;
        $app->log->info("Subrocess $pid stop");
        kill('INT', $pid);
    }
);

$server->run;
#EOF
