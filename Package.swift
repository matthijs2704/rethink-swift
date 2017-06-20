import PackageDescription

let package = Package(
	name: "Rethink",
	targets: [
		Target(name: "Rethink", dependencies: ["GCDAsyncSocket", "SCRAM"]),
		Target(name: "GCDAsyncSocket"),
		Target(name: "SCRAM")
	],
	dependencies: [
        .Package(url: "https://github.com/vapor/sockets.git", majorVersion: 2),
    ]
)
