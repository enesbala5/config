import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { run } from './cli.mjs';

const template = await readFile(new URL('workspaces.example.json', import.meta.url), 'utf8');
function fixture(platforms, accounts = [{ platform: 'twitter', _id: 'one' }], fields = {}) {
  const calls = [];
  const ws = JSON.parse(template); ws.workspaces.personal.key = 'test-only';
  return { calls, deps: {
    load: async () => JSON.stringify(ws), input: async () => JSON.stringify({content:'test', platforms, ...fields}),
    fetcher: async (url, options) => {
      calls.push({ url, ...options });
      return { ok:true, json:async () => url.endsWith('/accounts') ? { accounts } : { post: { _id:'post-1' } } };
    }
  }};
}
const cmd = (mode = 'draft') => [mode,'personal','--request-id','stable'];
test('account lookup uses selected key; draft resolves x and carries stable request id', async () => {
  const { calls, deps } = fixture([{platform:'x'}]);
  assert.deepEqual((await run(['accounts','personal'], deps)).map(a => a.accountId), ['one']);
  assert.equal((await run(cmd(), deps)).postId,'post-1');
  const req = calls.at(-1);
  assert.equal(req.headers.Authorization,'Bearer test-only'); assert.equal(req.headers['x-request-id'],'stable');
  assert.deepEqual(JSON.parse(req.body), {content:'test',platforms:[{platform:'twitter',accountId:'one'}],isDraft:true});
});
test('unconfigured, disconnected, ambiguous and conflicting modes never create', async () => {
  for (const [platform, accounts, fields] of [['facebook',[]], ['reddit',[]], ['x',[{platform:'twitter',_id:'1'},{platform:'twitter',_id:'2'}]], ['x',[],{publishNow:true}]]) {
    const { deps,calls } = fixture([{platform}], accounts, fields);
    await assert.rejects(run(cmd(), deps)); assert.ok(calls.every(r => r.method === 'GET'));
  }
});
test('empty template key rejected before any request', async () => {
  const { deps,calls } = fixture([]); deps.load = async () => template;
  await assert.rejects(run(['accounts','personal'], deps), /requires key/); assert.equal(calls.length,0);
});
test('explicit ID resolves duplicates on schedule, status only reads', async () => {
  const {deps,calls} = fixture([{platform:'x',accountId:'b'}], ['a','b'].map(_id=>({platform:'twitter',_id})), {scheduledFor:'2027-01-01T09:00:00',timezone:'UTC'});
  await run(cmd('schedule'),deps); assert.equal(JSON.parse(calls.at(-1).body).platforms[0].accountId,'b');
  await run(['status','personal','post-1'],deps); assert.equal(calls.at(-1).method,'GET');
});
