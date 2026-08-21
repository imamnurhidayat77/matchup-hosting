import { rtdb } from '../../database/firebase.js';
import { activityMessagesPath } from '../../database/paths.js';

export type ChatMessageType = 'text' | 'system';

export type ChatMessageRecord = {
    senderId: string;
    text: string;
    type: ChatMessageType;
    timestamp: number;
}

export type ChatMessageWithId = ChatMessageRecord & {
    messageId: string;
};

export async function sendMessage(activityId: string, senderId: string, text: string, messageType: ChatMessageType = 'text',): Promise<{ messageId: string }> {

    const normalizedActivityId = activityId.trim();
    const normalizedSenderId = senderId.trim();
    const normalizedText = text.trim();

    if (!normalizedActivityId) throw new Error('activityId is required');

    if (!normalizedSenderId) throw new Error ('senderId is required');

    if (!normalizedText){
        throw new Error('text is required');
    }

    if (messageType !== 'text' && messageType !== 'system') throw new Error ('messageType must be text or system');

    const messageRef = rtdb.ref(activityMessagesPath(normalizedActivityId)); 
    const newMessageRef = messageRef.push();

    await newMessageRef.set({
        senderId: normalizedSenderId,
        text: normalizedText,
        type : messageType,
        timestamp: Date.now(),
    } satisfies ChatMessageRecord) 

    return {
        messageId : newMessageRef.key as string,
    };
} 

export async function getMessages(activityId: string): Promise<ChatMessageWithId[]>{
    const normalizedActivityId = activityId.trim();
    
    if (!normalizedActivityId) throw new Error ('activityId is required');

    const snapshot = await rtdb.ref(activityMessagesPath(normalizedActivityId)).get();

    if(!snapshot.exists()) return [];

    const data = snapshot.val() as Record<string, Partial<ChatMessageRecord>> | null;

    if(!data) return [];

    const messages: ChatMessageWithId[] = [];

    for(const [messageId, value] of Object.entries(data)){
        if (!value) continue

        if (typeof value.senderId !== 'string') throw new Error ('Invalid chat message: senderId must be a string');

        if (typeof value.text !== 'string') throw new Error ('Invalid chat message: text must be a string');

        if (value.type !== 'text' && value.type !== 'system') throw new Error ('Invalid chat message: type must be text or system');

        if (typeof value.timestamp !== 'number') throw new Error ('Invalid chat message: timestamp must be a number');

        messages.push({
            messageId,
            senderId: value.senderId,
            text: value.text,
            type: value.type,
            timestamp: value.timestamp,
        });

    }

    messages.sort((a,b) => a.timestamp - b.timestamp);

    return messages;
}
