BEGIN TRANSACTION;
CREATE TABLE domains (
    id int unique NOT NULL PRIMARY KEY,
    name text unique,
    size int  DEFAULT 0,
    quota int  DEFAULT 1048576
);
CREATE TABLE users (
    id int unique NOT NULL PRIMARY KEY,
    name text,
    gecos text,
    domain_id int,
    password text,
    hash text,
    size int DEFAULT 0,
    quota int DEFAULT 10240
);
CREATE TABLE aliases (
    id int unique NOT NULL PRIMARY KEY,
    name text,
    domain_id int,
    list text
);
CREATE TABLE forwarded (
    id int unique NOT NULL PRIMARY KEY,
    name text unique
);
CREATE TABLE unwanted (
    id int unique NOT NULL PRIMARY KEY,
    name text unique
);
CREATE TABLE trusted (
    id int unique NOT NULL PRIMARY KEY,
    name text unique
);
COMMIT;
