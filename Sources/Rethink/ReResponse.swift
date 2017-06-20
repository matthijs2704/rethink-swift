/**  Rethink.swift
Copyright (c) 2016 Pixelspark
Author: Tommy van der Vorst (tommy@pixelspark.nl)

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE. **/
import Foundation

public enum ReError: Error {
	case fatal(String)
	case other(Error)

	public var localizedDescription: String {
		switch self {
		case .fatal(let d): return d
		case .other(let e): return e.localizedDescription
		}
	}
}

public enum ReResponse {
	public typealias Callback = (ReResponse) -> ()
	public typealias ContinuationCallback = (@escaping Callback) -> ()

	case error(String)
	case Value(Any)
	case rows([ReDocument], ContinuationCallback?)
	case unknown

	init?(json: Data, continuation: @escaping ContinuationCallback) {
		do {
			if let d = try JSONSerialization.jsonObject(with: json, options: []) as? NSDictionary {
				if let type = d.value(forKey: "t") as? NSNumber {
					switch type.intValue {
					case ReProtocol.responseTypeSuccessAtom:
						guard let r = d.value(forKey: "r") as? [Any] else { return nil }
						if r.count != 1 { return nil }
						self = .Value(ReDatum(jsonSerialization: r.first!).value)

					case ReProtocol.responseTypeSuccessPartial, ReProtocol.responseTypeSuccessSequence:
						if let r = d.value(forKey: "r") as? [[String: Any]] {
							let deserialized = r.map { (document) -> ReDocument in
								var dedoc: ReDocument = [:]
								for (k, v) in document {
									dedoc[k] = ReDatum(jsonSerialization: v).value
								}
								return dedoc
							}

							let ccb: ContinuationCallback? = (type.intValue == ReProtocol.responseTypeSuccessPartial) ? continuation: nil
							self = .rows(deserialized, ccb)
						}
						else if let r = d.value(forKey: "r") as? [Any] {
							let deserialized = r.map { (value) -> Any in
								return ReDatum(jsonSerialization: value).value
							}

							self = .Value(deserialized)
						}
						else {
							return nil
						}

					case ReProtocol.responseTypeClientError:
						guard let r = d.value(forKey: "r") as? [Any] else { return nil }
						if r.count != 1 { return nil }
						self = .error("Client error: \(r.first!)")

					case ReProtocol.responseTypeCompileError:
						guard let r = d.value(forKey: "r") as? [Any] else { return nil }
						if r.count != 1 { return nil }
						self = .error("Compile error: \(r.first!)")

					case ReProtocol.responseTypeRuntimeError:
						guard let r = d.value(forKey: "r") as? [Any] else { return nil }
						if r.count != 1 { return nil }
						self = .error("Run-time error: \(r.first!)")

					default:
						self = .unknown
					}
				}
				else {
					return nil
				}
			}
			else {
				return nil
			}
		}
		catch {
			return nil
		}
	}

	public var isError: Bool {
		switch self {
		case .error(_): return true
		default: return false
		}
	}

	public var value: Any? {
		switch self {
		case .Value(let v):
			return v
			
		default:
			return nil
		}
	}
}
