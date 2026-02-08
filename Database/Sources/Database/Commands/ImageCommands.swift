import Foundation
import SwiftData
import OSLog
import Abstractions
import CoreImage
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// swiftlint:disable nesting

// MARK: - Image Commands
public enum ImageCommands {
    public struct AddResponse: WriteCommand {
        private let messageId: UUID
        private let imageData: Data
        private let configuration: UUID
        private let prompt: String

        public init(
            messageId: UUID,
            imageData: Data,
            configuration: UUID,
            prompt: String
        ) {
            self.messageId = messageId
            self.imageData = imageData
            self.configuration = configuration
            self.prompt = prompt
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            let descriptor = FetchDescriptor<Message>(
                predicate: #Predicate<Message> { $0.id == messageId }
            )
            guard let message = try context.fetch(descriptor).first else {
                throw DatabaseError.messageNotFound
            }

            let descriptorConfig = FetchDescriptor<DiffusorConfiguration>(
                predicate: #Predicate<DiffusorConfiguration> { $0.id == configuration }
            )

            guard let configuration = try context.fetch(descriptorConfig).first else {
                throw DatabaseError.configurationNotFound
            }

            if let responseImage = message.responseImage {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                    responseImage.image = imageData
                    responseImage.configuration = configuration
                    responseImage.prompt = prompt
                }
                try context.save()
                return responseImage.id
            } else {
                let attachment = ImageAttachment(
                    image: imageData,
                    prompt: prompt,
                    configuration: configuration
                )
                withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                    message.responseImage = attachment
                    context.insert(attachment)
                }
                try context.save()
                return attachment.id
            }
        }
    }
    
    public struct AddImageResponse: WriteCommand {
        private let messageId: UUID
        private let cgImage: CGImage
        private let configuration: UUID
        private let prompt: String
        
        public init(
            messageId: UUID,
            cgImage: CGImage,
            configuration: UUID,
            prompt: String
        ) {
            self.messageId = messageId
            self.cgImage = cgImage
            self.configuration = configuration
            self.prompt = prompt
        }
        
        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            // Convert CGImage to Data
            let imageData = convertCGImageToData(cgImage)
            
            let descriptor = FetchDescriptor<Message>(
                predicate: #Predicate<Message> { $0.id == messageId }
            )
            guard let message = try context.fetch(descriptor).first else {
                throw DatabaseError.messageNotFound
            }
            
            let descriptorConfig = FetchDescriptor<DiffusorConfiguration>(
                predicate: #Predicate<DiffusorConfiguration> { $0.id == configuration }
            )
            
            guard let configuration = try context.fetch(descriptorConfig).first else {
                throw DatabaseError.configurationNotFound
            }
            
            if let responseImage = message.responseImage {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                    responseImage.image = imageData
                    responseImage.configuration = configuration
                    responseImage.prompt = prompt
                }
                try context.save()
                return responseImage.id
            } else {
                let attachment = ImageAttachment(
                    image: imageData,
                    prompt: prompt,
                    configuration: configuration
                )
                withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                    message.responseImage = attachment
                    context.insert(attachment)
                }
                try context.save()
                return attachment.id
            }
        }
        
        private func convertCGImageToData(_ cgImage: CGImage) -> Data {
            #if os(macOS)
            let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
            return bitmapRep.representation(using: .png, properties: [:]) ?? Data()
            #else
            let uiImage = UIImage(cgImage: cgImage)
            return uiImage.pngData() ?? Data()
            #endif
        }
    }

    public struct GetImageConfiguration: ReadCommand {
        public typealias Result = ImageConfiguration

        private let chat: UUID
        private let prompt: String
        private let negativePrompt: String?

        public init(
            chat: UUID,
            prompt: String,
            negativePrompt: String? = nil
        ) {
            self.chat = chat
            self.prompt = prompt
            self.negativePrompt = negativePrompt
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> ImageConfiguration {
            let descriptor = FetchDescriptor<Chat>(
                predicate: #Predicate<Chat> { $0.id == chat }
            )
            guard let chatModel = try context.fetch(descriptor).first else {
                throw DatabaseError.configurationNotFound
            }

            return chatModel
                .imageModelConfig
                .toSendable(
                prompt: prompt,
                negative: negativePrompt
            )
        }
    }

    struct GetResponse: ReadCommand {
        typealias Result = ImageAttachment?
        let messageId: UUID

        func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> ImageAttachment? {
            let descriptor = FetchDescriptor<Message>(
                predicate: #Predicate<Message> { $0.id == messageId }
            )
            guard let message = try context.fetch(descriptor).first else {
                throw DatabaseError.messageNotFound
            }
            return message.responseImage
        }
    }
}
