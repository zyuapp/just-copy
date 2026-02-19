import CoreGraphics
import CoreML
import Vision

enum OCRServiceError: LocalizedError {
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .noTextFound:
            return "No text was detected in the captured area."
        }
    }
}

final class OCRService {
    func recognizeText(in image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.01
        configureCPUOnlyExecution(for: request)

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard let observations = request.results, !observations.isEmpty else {
            throw OCRServiceError.noTextFound
        }

        let candidates: [(text: String, box: CGRect)] = observations.compactMap { observation in
            guard let topCandidate = observation.topCandidates(1).first else { return nil }

            let text = topCandidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return (text, observation.boundingBox)
        }

        guard !candidates.isEmpty else {
            throw OCRServiceError.noTextFound
        }

        let ordered = candidates.sorted { lhs, rhs in
            let yDistance = abs(lhs.box.midY - rhs.box.midY)
            if yDistance > 0.03 {
                return lhs.box.midY > rhs.box.midY
            }
            return lhs.box.minX < rhs.box.minX
        }

        let text = stitchLines(ordered)
        guard !text.isEmpty else {
            throw OCRServiceError.noTextFound
        }

        return text
    }

    private func configureCPUOnlyExecution(for request: VNRecognizeTextRequest) {
        if #available(macOS 14.0, *) {
            let cpuDevice = MLComputeDevice.allComputeDevices.first { device in
                if case .cpu = device { return true }
                return false
            }

            request.setComputeDevice(cpuDevice, for: .main)
            request.setComputeDevice(cpuDevice, for: .postProcessing)
        } else {
            request.usesCPUOnly = true
        }
    }

    private func stitchLines(_ lines: [(text: String, box: CGRect)]) -> String {
        var renderedLines: [String] = []
        var currentRowY: CGFloat?

        for line in lines {
            if let currentRowY, abs(currentRowY - line.box.midY) < 0.015 {
                let lastIndex = renderedLines.index(before: renderedLines.endIndex)
                renderedLines[lastIndex] += " " + line.text
            } else {
                renderedLines.append(line.text)
                currentRowY = line.box.midY
            }
        }

        return renderedLines.joined(separator: "\n")
    }
}
