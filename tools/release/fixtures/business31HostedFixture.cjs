'use strict';
// Synthetic raw platform messages only. No account, token, cloud or replay claim.
const fs = require('node:fs'), path = require('node:path'), Module = require('node:module'), { EventEmitter } = require('node:events'), zlib = require('node:zlib'), crypto = require('node:crypto');
function fixture() {
    const V = '1'.repeat(40), M = '2'.repeat(40), S = '3'.repeat(40), A = 'A'.repeat(64), now = Date.now();
    const trust = {
        schemaVersion: 1, profile: 'build31-business-hosted-recorded-replay-v1', repository: {
            name: 'fixture/repository', id: '1', ownerId: '2'
        }, workflow: {
            id: '7', path: '.github/workflows/business-private-replay.yml', ref: 'refs/tags/verifier-fixture', environment: 'fixture-read-only', jobName: 'Business private replay', actorIds: ['9']
        }, verifier: {
            commit: V, tree: '4'.repeat(40), files: Object.fromEntries(['Protocol', 'Replay', 'Result'].map(n => ['tools/release/business31Hosted' + n + '.cjs', A]))
        }, source: {
            commit: M, tree: '5'.repeat(40), functionsTree: '6'.repeat(40)
        }, sourceManifestSha256: A, nodeSha256: A, gitSha256: A, launcherSha256: A, pythonSha256: A, wifAudience: '//iam.googleapis.com/projects/123/locations/global/workloadIdentityPools/fixture/providers/github', maximumResultAgeSeconds: 3600
    };
    const request = {
        schemaVersion: 1, candidate: {
            commit: S, tree: '7'.repeat(40), ref: 'refs/pull/4/head', kind: 'pull_request', pullRequest: 4
        }, descriptorPointer: {
            commit: '8'.repeat(40), file: 'release/evidence/build31-business-private-replay.json', sha256: A
        }, runId: '42', runAttempt: '1'
    };
    const repository = {
        id: 1, full_name: trust.repository.name, owner: {
            id: 2
        }, private: false
    };
    const candidate = {
        number: 4, state: 'open', head: {
            sha: S, repo: {
                id: 1, full_name: trust.repository.name
            }
        }, base: {
            ref: 'main', repo: {
                id: 1
            }
        }
    };
    const run = {
        id: 42, run_attempt: 1, workflow_id: 7, path: trust.workflow.path, head_sha: V, event: 'workflow_dispatch', head_branch: 'verifier-fixture', repository: {
            id: 1
        }, head_repository: {
            id: 1
        }, actor: {
            id: 9
        }, triggering_actor: {
            id: 9
        }, status: 'completed', conclusion: 'success'
    };
    const job = {
        id: 51, name: trust.workflow.jobName, run_id: 42, head_sha: V, status: 'completed', conclusion: 'success', started_at: new Date(now - 60000).toISOString(), completed_at: new Date(now - 1000).toISOString()
    };
    const result = {
        schemaVersion: 1, documentType: 'build31-business-hosted-result', profile: trust.profile, verifier: {
            commit: V, tree: trust.verifier.tree
        }, source: trust.source, candidate: request.candidate, descriptorPointer: request.descriptorPointer, closurePointer: {
            commit: '9'.repeat(40), file: 'release/evidence/build31-business-backend-deployment-closure.json', sha256: A
        }, commitments: {
            bundleSha256: A, membersSha256: A, relocationSha256: A, sourceManifestSha256: A
        }, platform: {
            repositoryId: '1', workflowId: '7', workflowCommit: V, runId: '42', runAttempt: '1', environment: trust.workflow.environment
        }, startedAtUtc: new Date(now - 50000).toISOString(), completedAtUtc: new Date(now - 2000).toISOString(), recordedSemanticsReplayed: true, limits: {
            ownerIdentityAuthenticated: false, originalProcessExecutionAuthenticated: false, deploymentAuthorized: false, constructionAuthorized: false, distributionAuthorized: false
        }
    };
    const claims = {
        iss: 'https://token.actions.githubusercontent.com', aud: trust.wifAudience, repository: trust.repository.name, repository_id: '1', repository_owner_id: '2', repository_visibility: 'public', workflow_ref: trust.repository.name + '/' + trust.workflow.path + '@' + trust.workflow.ref, workflow_sha: V, sha: V, ref: trust.workflow.ref, event_name: 'workflow_dispatch', run_id: '42', run_attempt: '1', runner_environment: 'github-hosted', environment: trust.workflow.environment, sub: 'repo:' + trust.repository.name + ':environment:' + trust.workflow.environment, actor_id: '9', iat: Math.floor(now / 1000) - 10, nbf: Math.floor(now / 1000) - 10, exp: Math.floor(now / 1000) + 290
    };
    return {
        trust, request, repository, candidate, run, job, result, claims
    };
}
function signed(claims, keypair) {
    const head = {
        alg: 'RS256', kid: 'synthetic-key', typ: 'JWT'
    };
    const body = [head, claims].map(x => Buffer.from(JSON.stringify(x)).toString('base64url')).join('.');
    return body + '.' + crypto.sign('RSA-SHA256', Buffer.from(body), keypair.privateKey).toString('base64url');
}
function keys() {
    const pair = crypto.generateKeyPairSync('rsa', {
        modulusLength: 2048
    });
    return {
        ...pair, jwks: {
            keys: [{
                    ...pair.publicKey.export({
                        format: 'jwk'
                    }), alg: 'RS256', kid: 'synthetic-key', use: 'sig'
                }]
        }
    };
}
function crc(b) {
    let c = 0xffffffff;
    for (const x of b) {
        c ^= x;
        for (let i = 0; i < 8; i++)
            c = (c >>> 1) ^ (0xedb88320 & -(c & 1));
    }
    return (c ^ 0xffffffff) >>> 0;
}
function zip(value, { streamed = false, name = 'business31-hosted-result.json', method = 8 } = {}) {
    const raw = Buffer.from(JSON.stringify(value)), body = method === 8 ? zlib.deflateRawSync(raw) : raw, n = Buffer.from(name), flags = streamed ? 8 : 0, c = crc(raw), local = Buffer.alloc(30), central = Buffer.alloc(46), end = Buffer.alloc(22);
    local.writeUInt32LE(0x04034b50);
    local.writeUInt16LE(20, 4);
    local.writeUInt16LE(flags, 6);
    local.writeUInt16LE(method, 8);
    if (!streamed) {
        local.writeUInt32LE(c, 14);
        local.writeUInt32LE(body.length, 18);
        local.writeUInt32LE(raw.length, 22);
    }
    local.writeUInt16LE(n.length, 26);
    const dd = Buffer.alloc(streamed ? 16 : 0);
    if (streamed) {
        dd.writeUInt32LE(0x08074b50);
        dd.writeUInt32LE(c, 4);
        dd.writeUInt32LE(body.length, 8);
        dd.writeUInt32LE(raw.length, 12);
    }
    central.writeUInt32LE(0x02014b50);
    central.writeUInt16LE(20, 4);
    central.writeUInt16LE(20, 6);
    central.writeUInt16LE(flags, 8);
    central.writeUInt16LE(method, 10);
    central.writeUInt32LE(c, 16);
    central.writeUInt32LE(body.length, 20);
    central.writeUInt32LE(raw.length, 24);
    central.writeUInt16LE(n.length, 28);
    const prefix = Buffer.concat([
        local, n, body, dd
    ]);
    end.writeUInt32LE(0x06054b50);
    end.writeUInt16LE(1, 8);
    end.writeUInt16LE(1, 10);
    end.writeUInt32LE(central.length + n.length, 12);
    end.writeUInt32LE(prefix.length, 16);
    return Buffer.concat([
        prefix, central, n, end
    ]);
}
function loadFakePlatform(routes) {
    const requests = [], https = {
        request(url, options, callback) {
            const req = new EventEmitter();
            req.destroy = () => { };
            req.end = (body) => {
                const record = {
                    url: String(url), method: options.method, headers: options.headers, body: body ? Buffer.from(body) : null
                };
                requests.push(record);
                queueMicrotask(() => {
                    try {
                        const response = routes(record, requests.length);
                        const res = new EventEmitter();
                        res.statusCode = response.status ?? 200;
                        res.headers = response.headers ?? {};
                        res.complete = response.complete !== false;
                        callback(res);
                        const bytes = Buffer.isBuffer(response.body) ? response.body : Buffer.from(JSON.stringify(response.body));
                        res.emit('data', bytes);
                        res.emit('end');
                    }
                    catch (e) {
                        req.emit('error', e);
                    }
                });
            };
            return req;
        }
    };
    const base = path.resolve(__dirname, '..');
    function load(file, protocol) { const absolute = path.join(base, file), m = new Module(absolute, module); m.filename = absolute; m.paths = []; m.require = name => name === 'node:https' ? https : name === './business31HostedProtocol.cjs' ? protocol : require(name.startsWith('./') ? path.resolve(base, name) : name); m._compile(fs.readFileSync(absolute, 'utf8'), absolute); return m.exports; }
    const protocol = load('business31HostedProtocol.cjs');
    function runEntry(file, input, trust, { preload = false, clientInput, clientSha256,
        omitClientSha256 = false, extraClientArgs = [], missingClientHelper } = {}) {
        const os = require('node:os'), root = fs.mkdtempSync(path.join(os.tmpdir(), 'business-hosted-fixture-'));
        const selected = structuredClone(trust);
        selected.nodeSha256 = crypto.createHash('sha256').update(fs.readFileSync(process.execPath)).digest('hex').toUpperCase();
        selected.verifier.files = {...(clientInput === undefined && input.schemaVersion !== 2 && input.request?.schemaVersion !== 2 ? {} : selected.verifier.files),
            ...Object.fromEntries(['Protocol', 'Replay', 'Result'].map(n => { const name = 'business31Hosted' + n + '.cjs'; return ['tools/release/' + name, crypto.createHash('sha256').update(fs.readFileSync(path.join(base, name))).digest('hex').toUpperCase()]; }))};
        if (missingClientHelper) delete selected.verifier.files[missingClientHelper];
        const trustFile = path.join(root, 'trust.json'), requestFile = path.join(root, 'input.json');
        fs.writeFileSync(trustFile, JSON.stringify(selected));
        fs.writeFileSync(requestFile, JSON.stringify(input));
        const trustSha = crypto.createHash('sha256').update(fs.readFileSync(trustFile)).digest('hex').toUpperCase();
        return new Promise((resolve, reject) => {
            const filename = path.join(base, file), m = {
                exports: {}
            }, cache = {
                [filename]: m
            };
            if (preload)
                cache['unselected-helper.cjs'] = {
                    exports: {}
                };
            const requireTest = name => name === './business31HostedProtocol.cjs' ? protocol :
                require(name.startsWith('./') ? path.resolve(base, name) : name);
            requireTest.main = m;
            requireTest.cache = cache;
            const proc = {
                execPath: process.execPath, execArgv: ['--no-global-search-paths'], argv: [
                    process.execPath, filename, '--trust', trustFile, '--trust-sha256', trustSha, '--request', requestFile
                ], env: {
                    GITHUB_TOKEN: 'synthetic-token-never-a-real-credential'
                }, exitCode: 0, stdout: {
                    write(text) { resolve(JSON.parse(text)); }
                }, stderr: {
                    write(text) { reject(Error(String(text).trim())); }
                }
            };
            if (file === 'business31HostedReplay.cjs')
                proc.argv.push('--output', path.join(root, 'business31-hosted-result.json'));
            if (clientInput !== undefined) {
                const clientFile = path.join(root, 'client-input.json');
                fs.writeFileSync(clientFile, JSON.stringify(clientInput));
                proc.argv.push('--client-input', clientFile);
                if (!omitClientSha256) proc.argv.push('--client-input-sha256', clientSha256 ??
                    crypto.createHash('sha256').update(fs.readFileSync(clientFile)).digest('hex').toUpperCase());
            }
            proc.argv.push(...extraClientArgs);
            try {
                const execute = new Function('require', 'module', 'exports', '__dirname', '__filename', 'process', fs.readFileSync(filename, 'utf8'));
                execute(requireTest, m, m.exports, base, filename, proc);
            }
            catch (e) {
                reject(e);
            }
        }).finally(() => fs.rmSync(root, {
            recursive: true, force: true
        }));
    }
    return {
        protocol, requests, runConsumer: ({ trust, request }, options) => runEntry('business31HostedResult.cjs', request, trust, options), runReplay: (trust, input, options) => runEntry('business31HostedReplay.cjs', input, trust, options)
    };
}
function platform(f, { mutate, afterFirstHead, zipOptions } = {}) {
    const raw = zip(f.result, zipOptions), a = {
        id: 71, name: 'business31-hosted-' + f.request.candidate.commit + '-42-1', expired: false, size_in_bytes: raw.length, digest: 'sha256:' + crypto.createHash('sha256').update(raw).digest('hex'), workflow_run: {
            id: 42, repository_id: 1, head_repository_id: 1, head_sha: f.trust.verifier.commit
        }, created_at: new Date(Date.parse(f.job.completed_at) - 500).toISOString(), expires_at: new Date(Date.now() + 3600000).toISOString()
    };
    let heads = 0;
    return loadFakePlatform((record) => {
        const u = new URL(record.url), suffix = u.pathname.replace('/repos/fixture/repository', '');
        let reply;
        if (u.hostname === 'fixture.blob.core.windows.net') {
            reply = {
                body: raw
            };
        }
        else if (suffix === '')
            reply = {
                body: f.repository
            };
        else if (suffix === '/actions/runs/42')
            reply = {
                body: f.run
            };
        else if (suffix === '/actions/runs/42/attempts/1/jobs')
            reply = {
                body: {
                    total_count: 1, jobs: [f.job]
                }
            };
        else if (suffix === '/pulls/4') {
            heads++;
            reply = {
                body: heads > 1 && afterFirstHead ? afterFirstHead : f.candidate
            };
        }
        else if (suffix === '/actions/runs/42/artifacts')
            reply = {
                body: {
                    total_count: 1, artifacts: [a]
                }
            };
        else if (suffix === '/actions/artifacts/71/zip')
            reply = {
                status: 302, headers: {
                    location: 'https://fixture.blob.core.windows.net/result?sig=synthetic'
                }, body: Buffer.alloc(0)
            };
        else
            throw Error('Unplanned synthetic request');
        if (!mutate)
            return reply;
        const copy = structuredClone(reply);
        if (Buffer.isBuffer(reply.body))
            copy.body = Buffer.from(reply.body);
        return mutate(record, copy);
    });
}
module.exports = {
    fixture, signed, keys, zip, loadFakePlatform, platform
};
