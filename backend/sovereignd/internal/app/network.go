package app

import (
	"net"
	"strconv"
)

func getFreeLocalPort() (int, error) {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return 0, err
	}
	defer listener.Close()

	addr, ok := listener.Addr().(*net.TCPAddr)
	if !ok {
		return 0, nil
	}

	return addr.Port, nil
}

func getLANIPv4() string {
	ifaces, err := net.Interfaces()
	if err != nil {
		return ""
	}

	for _, iface := range ifaces {
		if (iface.Flags&net.FlagUp) == 0 || (iface.Flags&net.FlagLoopback) != 0 {
			continue
		}

		addrs, err := iface.Addrs()
		if err != nil {
			continue
		}

		for _, addr := range addrs {
			var ip net.IP
			switch value := addr.(type) {
			case *net.IPNet:
				ip = value.IP
			case *net.IPAddr:
				ip = value.IP
			}

			if ip == nil {
				continue
			}

			ip4 := ip.To4()
			if ip4 == nil {
				continue
			}

			return ip4.String()
		}
	}

	return ""
}

func buildURLs(proto string, port int) (localURL string, lanURL string) {
	if proto == "" {
		proto = defaultServiceProtoHTTP
	}

	localURL = proto + "://localhost:" + strconv.Itoa(port)

	lanIP := getLANIPv4()
	if lanIP != "" {
		lanURL = proto + "://" + lanIP + ":" + strconv.Itoa(port)
	}

	return localURL, lanURL
}
