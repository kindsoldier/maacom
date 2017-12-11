BEGIN TRANSACTION;
CREATE TABLE domains (
    id int unique NOT NULL PRIMARY KEY,
    name text unique,
    size int  DEFAULT 0,
    quota int  DEFAULT 0
);
CREATE TABLE users (
    id int unique NOT NULL PRIMARY KEY,
    name text,
    domain_id int,
    password text,
    hash text,
    size int DEFAULT 0,
    quota int  DEFAULT 0
);
CREATE TABLE aliases (
    id int unique NOT NULL PRIMARY KEY,
    name text,
    domain_id int,
    list text
);
CREATE TABLE forwards (
    id int unique NOT NULL PRIMARY KEY,
    name text unique
);

COMMIT;
