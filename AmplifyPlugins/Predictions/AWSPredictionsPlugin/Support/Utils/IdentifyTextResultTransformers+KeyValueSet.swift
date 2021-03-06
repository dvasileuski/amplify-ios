//
// Copyright 2018-2020 Amazon.com,
// Inc. or its affiliates. All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import Amplify
import AWSTextract

extension IdentifyTextResultTransformers {

    static func processKeyValues(keyValueBlocks: [AWSTextractBlock],
                                 blockMap: [String: AWSTextractBlock]) -> [BoundedKeyValue] {
        var keyValues =  [BoundedKeyValue]()
        for keyValueBlock in keyValueBlocks {
            if let keyValue = processKeyValue(keyValueBlock, blockMap: blockMap) {
                keyValues.append(keyValue)
            }
        }
        return keyValues
    }

    static func processKeyValue(_ keyBlock: AWSTextractBlock,
                                blockMap: [String: AWSTextractBlock]) -> BoundedKeyValue? {
        guard keyBlock.blockType == .keyValueSet,
            keyBlock.entityTypes?.contains("KEY") ?? false,
            let relationships = keyBlock.relationships else {
            return nil
        }

        var keyText = ""
        var valueText = ""
        var valueSelected = false

        for keyBlockRelationship in relationships {
            guard let ids = keyBlockRelationship.ids else {
                continue
            }

            switch keyBlockRelationship.types {
            case .child:
                keyText = processChildOfKeyValueSet(ids: ids, blockMap: blockMap)
            case .value:
                let valueResult = processValueOfKeyValueSet(ids: ids, blockMap: blockMap)
                valueText = valueResult.0
                valueSelected = valueResult.1
            default:
                break
            }
        }

        guard let boundingBox = processBoundingBox(keyBlock.geometry?.boundingBox) else {
            return nil
        }

        guard let polygon = processPolygon(keyBlock.geometry?.polygon) else {
            return nil
        }

        return BoundedKeyValue(key: keyText,
                               value: valueText,
                               isSelected: valueSelected,
                               boundingBox: boundingBox,
                               polygon: polygon)
    }

    static func processChildOfKeyValueSet(ids: [String],
                                          blockMap: [String: AWSTextractBlock]) -> String {
        var keyText = ""
        for keyId in ids {
            guard let keyBlock = blockMap[keyId],
                let text = keyBlock.text,
                case .word = keyBlock.blockType else {
                continue
            }
            keyText += text + " "
        }
        return keyText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func processValueOfKeyValueSet(ids: [String],
                                          blockMap: [String: AWSTextractBlock]) -> (String, Bool) {
        var valueText = ""
        var isSelected = false
        var selectionItemFound = false

        for valueId in ids {
            guard let valueBlock = blockMap[valueId],
                let valueBlockRelations = valueBlock.relationships else {
                continue
            }

            for valueBlockRelation in valueBlockRelations {
                guard let wordBlockIds = valueBlockRelation.ids else {
                    break
                }

                for wordBlockId in wordBlockIds {
                    guard let wordBlock = blockMap[wordBlockId] else {
                        continue
                    }
                    let wordValueBlockType = wordBlock.blockType
                    let selectionStatus = wordBlock.selectionStatus

                    switch wordValueBlockType {
                    case .word:
                        if let text = wordBlock.text {
                            valueText += text + " "
                        }
                    case .selectionElement:
                        if !selectionItemFound {
                            selectionItemFound = true
                            //TODO: https://github.com/aws-amplify/amplify-ios/issues/695
                            // Support multiple selection items found in a KeyValueSet
                            isSelected = selectionStatus == .selected
                        } else {
                            Amplify.log.error("Multiple selection items found in KeyValueSet")
                        }
                    default: break
                    }
                }
            }
        }
        return (valueText.trimmingCharacters(in: .whitespacesAndNewlines), isSelected)
    }
}
