import json, os, boto3, ipaddress, logging
logging.getLogger().setLevel(logging.INFO)
wafv2=boto3.client("wafv2"); sns=boto3.client("sns")
WAF_IPSET_ID=os.environ["WAF_IPSET_ID"]; WAF_SCOPE=os.environ.get("WAF_SCOPE","REGIONAL")
WAF_NAME=os.environ["WAF_NAME"]; SNS_TOPIC_ARN=os.environ["SNS_TOPIC_ARN"]
BLOCK_CIDR=os.environ.get("BLOCK_CIDR","auto")

def _extract_attacker_ip(e):
    d=e.get("detail",{}); a=d.get("service",{}).get("action",{})
    for ip in [a.get("remoteIpDetails",{}).get("ipAddressV4"),
               a.get("awsApiCallAction",{}).get("remoteIpDetails",{}).get("ipAddressV4"),
               a.get("networkConnectionAction",{}).get("remoteIpDetails",{}).get("ipAddressV4"),
               a.get("portProbeAction",{}).get("remoteIpDetails",{}).get("ipAddressV4")]:
        if ip: return ip
    return None

def _normalize_cidr(ip):
    if BLOCK_CIDR=="auto":
        try: ipaddress.IPv4Address(ip); return f"{ip}/32"
        except Exception: pass
    return ip

def _publish(msg, sub="GuardDuty Auto-Response"):
    try: sns.publish(TopicArn=SNS_TOPIC_ARN, Subject=sub, Message=msg)
    except Exception as e: logging.error(f"SNS publish failed: {e}")

def handler(event, context):
    logging.info("Event: %s", json.dumps(event))
    ip=_extract_attacker_ip(event)
    if not ip: logging.info("No attacker IP found."); return {"status":"noop"}
    cidr=_normalize_cidr(ip); logging.info(f"IP {ip} -> CIDR {cidr}")
    try:
        ipset=wafv2.get_ip_set(Name=WAF_NAME, Scope=WAF_SCOPE, Id=WAF_IPSET_ID)
        token=ipset["LockToken"]; addrs=set(ipset["IPSet"]["Addresses"] or [])
    except Exception as e:
        logging.error(f"GetIPSet failed: {e}"); _publish(f"❌ No se pudo leer IPSet: {e}"); raise
    if cidr in addrs:
        _publish(f"ℹ️ IP {cidr} ya estaba bloqueada en WAF."); return {"status":"exists","cidr":cidr}
    addrs.add(cidr)
    try:
        wafv2.update_ip_set(Name=WAF_NAME, Scope=WAF_SCOPE, Id=WAF_IPSET_ID,
                            Addresses=sorted(list(addrs)), LockToken=token)
        msg=f"🛡️ IP {cidr} agregada a IPSet '{WAF_NAME}'."
        logging.info(msg); _publish(msg); return {"status":"added","cidr":cidr}
    except Exception as e:
        logging.error(f"UpdateIPSet failed: {e}"); _publish(f"❌ Error WAF con {cidr}: {e}"); raise
