import Foundation

/**
 当前匹配阶段中可用的信息。

 由于我们想加快速度，因此我们首先匹配请求而不解决它（.Domain`）。 如果有任何规则返回“ .Unknown”，我们将查找请求并重新匹配该规则（“ .IP”）。

 -域：仅域信息可用。
 -IP：IP地址已解析。
 */
public enum DNSSessionMatchType {
    case domain, ip
}
