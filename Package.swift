import PackageDescription

let package = Package(
	name: "Rethink",
	targets: [
		Target(name: "Rethink", dependencies: ["SCRAM"]),
		Target(name: "SCRAM")
	],
	dependencies: [
        .Package(url: "https://github.com/vapor/sockets.git", majorVersion: 2),
        .Package(url: "https://github.com/vapor/crypto.git", majorVersion: 2),
        .Package(url: "https://github.com/vapor/bcrypt.git", majorVersion: 1),
    ]
)
