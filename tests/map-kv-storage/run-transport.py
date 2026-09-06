#!/usr/bin/env python3
"""Evaluate production string literal in ManiaScript; no map metadata writes."""
import hashlib,json,pathlib,subprocess,time,uuid
here=pathlib.Path(__file__).resolve().parent
def find_control_mcp_call(start):
    """tm-control-mcp is a sibling of the plugin checkout, but a git worktree
    sits one level deeper (.worktrees/<branch>/), so walk up for it."""
    for base in [start] + list(start.parents):
        candidate = base.parent / 'tm-control-mcp/tools/call.py'
        if candidate.exists():
            return candidate
    raise SystemExit('tm-control-mcp/tools/call.py not found near ' + str(start))

repo=here.parent.parent
run_id=time.strftime('%Y%m%dT%H%M%S',time.gmtime())+'-'+uuid.uuid4().hex[:8]
subprocess.run([str(here/'transport/build.sh'),run_id],check=True)
stage=pathlib.Path('/tmp')/('epp-kv-transport-'+run_id)
fixture=pathlib.Path.home()/'tm-docs/Tests/EppKVTransport'/run_id
call_script=find_control_mcp_call(repo)
log=pathlib.Path.home()/'OpenplanetNext/Openplanet.log'
log_offset=log.stat().st_size

def call(tool,args):
    response=json.loads(subprocess.check_output(['python3',str(call_script),tool,json.dumps(args)],text=True))
    with (fixture/'rpc.jsonl').open('a') as stream:
        stream.write(json.dumps({'tool':tool,'response':response})+'\n')
    if not response.get('ok') or not response.get('data',{}).get('result',{}).get('success'):
        raise RuntimeError(json.dumps(response))
    return response

try:
    loaded=call('ControlPlugin',{'action':'load','path':str(stage)+'/'})
    (fixture/'load.json').write_text(json.dumps(loaded,indent=2))
    deadline=time.monotonic()+5
    while not (fixture/'literal.txt').exists() and time.monotonic()<deadline: time.sleep(0.05)
    literal=(fixture/'literal.txt').read_text()
finally:
    call('ControlPlugin',{'action':'unload','id':stage.name})
# First measure one full result event. The subsequent sliced observation is
# needed only if the tool cannot return the full payload in one cell.
event='EppKVTransport_'+run_id.replace('-','_')
script_start='#Include "TextLib" as TL\nmain() {\n    declare Text Value = '+literal+';\n'
expected=(fixture/'expected.txt').read_bytes()

def observe(label,body):
    script=script_start+body+'}\n'
    (fixture/(label+'.Script.txt')).write_text(script)
    request={'script':script,'context':'in-editor','pageUid':event,'replace':True,'persist':False,'waitMs':250,'collectMs':1000,'resultEvent':event}
    response=call('RunManialinkScript',request)
    (fixture/(label+'-response.json')).write_text(json.dumps(response,indent=2,ensure_ascii=False))
    output=response['data']['result']['output']
    assert output['executionConfirmed'] and output['removedAfter']
    return output

single=observe('single-event','    SendCustomEvent("MLHook_Event_'+event+'", [Value]);\n')
assert single['resultCount']==1
single_bytes=single['results'][0]['data'].encode('utf-8')
single_observation={'receivedBytes':len(single_bytes),'matchesFullPayload':single_bytes==expected,'endsWithEllipsis':single_bytes.endswith('…'.encode('utf-8'))}
actual=single_bytes
output=single
if actual!=expected:
    body=''
    # SubString is used in production ManiaScript. Independent events preserve
    # tabs/newlines verbatim in each result's data field.
    for start in (0,3000,6000,9000):
        body+='    SendCustomEvent("MLHook_Event_'+event+'", [TL::SubString(Value, '+str(start)+', 3000)]);\n'
    output=observe('four-events',body)
    assert output['resultCount']==4
    actual=''.join(row['data'] for row in output['results']).encode('utf-8')
(fixture/'actual.txt').write_bytes(actual)
assert actual==expected, f'payload mismatch expected {len(expected)} bytes, received {len(actual)}'
receipt={'passed':True,'scope':'native production literal generation and ManiaScript evaluation; no map writes','payloadBytes':len(actual),'payloadSha256':hashlib.sha256(actual).hexdigest(),'singleEvent':single_observation,'comparisonEvents':output['resultCount'],'removedAfter':output['removedAfter'],'run':run_id}
(fixture/'verified.json').write_text(json.dumps(receipt,indent=2)+'\n')
with log.open('rb') as stream:
    stream.seek(log_offset);(fixture/'native.log').write_bytes(stream.read())
print(json.dumps(receipt,indent=2));print('Evidence: '+str(fixture))
