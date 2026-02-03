import {
  WebSocketGateway,
  SubscribeMessage,
  MessageBody,
  ConnectedSocket,
  OnGatewayConnection,
  OnGatewayDisconnect,
  WebSocketServer,
  OnGatewayInit,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from 'src/auth/guards/jwt-auth.guard';
import { ConnectedUser } from 'src/auth/decorator/user.decorator';
import { ChatService } from './chat.service';
import { SendMessageDto } from './dto/send-message.dto';
import { JwtPayload } from 'src/auth/jwt-payload.interface';
import * as jwt from 'jsonwebtoken';
import { ConfigService } from 'src/config/config.service';
import { WsObjectConvertPipe } from 'src/ws-object-convert/ws-object-convert.pipe';

interface ConnectedUserInfo {
  userId: number;
  username: string;
  companyCode: string;
}


/*
  to connect must include the token in auth object and the chat room id in the request URL
  Example:
  const socket = io('http://localhost:3000/chat?roomId=123', {
    auth: {
      token: 'Bearer ...'
}}  });
*/

@UseGuards(JwtAuthGuard)
@WebSocketGateway({
  cors: {
    origin: '*',
  },
  namespace: 'chat',
})
export class ChatGateway implements OnGatewayConnection, OnGatewayDisconnect, OnGatewayInit {
  @WebSocketServer()
  server: Server;

  private secret: string;
  private chatRooms = new  Map<number, ConnectedUserInfo[]>(); // Track by companyCode

  constructor(
    private readonly chatService: ChatService,
    private readonly configService: ConfigService,
  ) {
    const secret = this.configService.getJwtConfig().jwtSecret;
    if (!secret) throw new Error('JWT_SECRET is not defined');
    this.secret = secret;
  }

  afterInit(server: Server) {
    console.log('Chat Gateway initialized');
    server.use((socket, next) => {
          // Verify JWT for ALL connections
          try {
            let token = socket.handshake.auth.token;
            if(!token) {
              throw new Error('No token provided');
            }
            if(token.startsWith('Bearer ')) {
              token = token.slice(7, token.length).trim();
            }
            const user = jwt.verify(token, this.secret) as unknown as JwtPayload;
            socket.data.user = user;
            next();
          } catch (err) {
            next(new Error('Unauthorized'));
          }
        });
  }

  async handleConnection(client: Socket) {
    try {
      const user = client.data.user as JwtPayload;
      

      const roomId = parseInt(client.handshake.query.roomId as string);
      if(!roomId) {
        console.error('No roomId provided in connection query');
        client.disconnect();
        return;
      }
      client.data.roomId = roomId;
      // check if user is alowed to access this chat room
      if(!(await this.chatService.checkUserAccessToChatRoom(user, roomId))) {
        console.error(`User ${user.username} not allowed to access chat room ${roomId}`);
        client.disconnect();
        return;
      }

      // Join chat room
      const chatRoom = `${user.companyCode}-${roomId}`;
      client.join(chatRoom);

      this.addUserToRoom(user, roomId);
      
      const connectedUsers = this.chatRooms.get(roomId) || [];

      // Send current connected users to the newly connected client
      client.emit('connectedUsers', connectedUsers);

      // Notify others in company that user is online (but not the user themselves)
      client.to(chatRoom).emit('userOnline', {
        userId: user.sub,
        username: user.username,
      });

    } catch (error) {
      console.error('Socket auth failed:', error.message);
      client.disconnect();
    }
  }

  async handleDisconnect(client: Socket) {
    try {
      const user: JwtPayload = client.data.user;
      
      if (!user) return;
      const roomId: number = client.data.roomId;
      const index = this.chatRooms.get(roomId)?.findIndex(u => u.userId === user.sub);
      if (index === -1 || index === undefined) return;
      this.chatRooms.get(roomId)?.splice(
        index,
        1
      );
      if( this.chatRooms.get(roomId)?.length === 0){
        this.chatRooms.delete(roomId);
      }

      console.log(`Chat disconnected: ${user.username} (${user.sub})`);
      this.server.to(`${user.companyCode}-${roomId}`).emit('userOffline', {
        userId: user.sub,
        username: user.username,
      });
    } catch (error) {
      console.error('Disconnect error:', error);
    }
  }



  @SubscribeMessage('sendMessage')
  async handleMessage(
    @MessageBody(WsObjectConvertPipe) data: SendMessageDto,
    @ConnectedSocket() client: Socket,
    @ConnectedUser() user: JwtPayload,
  ) {
    if (!user) return;

    console.log(`Message from ${user.username}:`, data);
    
    try {
      // Validate message content
      if (!data.content?.trim()) {
        client.emit('error', {
          message: 'Message content cannot be empty',
        });
        return { success: false, error: 'Message content cannot be empty' };
      }

      if (data.content.length > 1000) {
        client.emit('error', {
          message: 'Message is too long',
        });
        return { success: false, error: 'Message is too long' };
      }

      const message = await this.chatService.sendMessage(data, user, client.data.roomId);
      
      // Send to company room (this will include the sender)
      const chatRoom = `${user.companyCode}-${client.data.roomId}`;
      this.server.to(chatRoom).emit('newMessage', {
        chatId: client.data.roomId,
        message,
      });

      return { success: true, message };
    } catch (error) {
      console.error('Send message error:', error);
      client.emit('error', {
        message: error.message || 'Failed to send message',
      });
      return { success: false, error: error.message };
    }
  }



  /*
  currently not used, but can be if we implement multiple chat rooms per user
  */
  @SubscribeMessage('joinChat')
  async handleJoinChat(
    @MessageBody(WsObjectConvertPipe) data: { chatId: number },
    @ConnectedSocket() client: Socket,
    @ConnectedUser() user: JwtPayload,
  ) {
    if (!user) return;

    try {
      // Verify user has access to this chat
      const hasAccess = true; // You should implement proper access check here
      if (!hasAccess) {
        client.emit('error', {
          message: 'You do not have access to this chat',
        });
        return { success: false, error: 'Access denied' };
      }

      const chatRoom = `${user.companyCode}-${data.chatId}`;
      client.join(chatRoom);
      
      console.log(`User ${user.username} joined chat room: ${chatRoom}`);
      
      // Notify others in the chat (not the user themselves)
      client.to(chatRoom).emit('userJoinedChat', {
        userId: user.sub,
        username: user.username,
        chatId: data.chatId,
      });

      return { success: true };
    } catch (error) {
      console.error('Join chat error:', error);
      return { success: false, error: error.message };
    }
  }


  /*
  currently not used, but can be if we implement multiple chat rooms per user
  */

  @SubscribeMessage('leaveChat')
  async handleLeaveChat(
    @MessageBody(WsObjectConvertPipe) data: { chatId: number },
    @ConnectedSocket() client: Socket,
    @ConnectedUser() user: JwtPayload,
  ) {
    if (!user) return;

    try {
      const chatRoom = `${user.companyCode}-${data.chatId}`;
      client.leave(chatRoom);
      
      console.log(`User ${user.username} left chat room: ${chatRoom}`);
      
      // Notify others in the chat (not the user themselves)
      client.to(chatRoom).emit('userLeftChat', {
        userId: user.sub,
        username: user.username,
        chatId: data.chatId,
      });

      return { success: true };
    } catch (error) {
      console.error('Leave chat error:', error);
      return { success: false, error: error.message };
    }
  }

  @SubscribeMessage('typing')
  async handleTyping(
    @MessageBody(WsObjectConvertPipe) data: { chatId: number, isTyping: boolean },
    @ConnectedSocket() client: Socket,
    @ConnectedUser() user: JwtPayload,
  ) {
    if (!user) return;

    try {
      const chatRoom = `${user.companyCode}-${data.chatId}`;
      
      // Only send to others in the chat, not the sender
      client.to(chatRoom).emit('userTyping', {
        userId: user.sub,
        username: user.username,
        chatId: data.chatId,
        isTyping: data.isTyping,
      });

      return { success: true };
    } catch (error) {
      console.error('Typing error:', error);
      return { success: false, error: error.message };
    }
  }

  @SubscribeMessage('getOnlineUsers')
  async handleGetOnlineUsers(@ConnectedUser() user: JwtPayload) {
    if (!user) return;
    const roomId = parseInt(user.companyCode as unknown as string);

    try {
      const connectedUsers = this.chatRooms.get(roomId) || [];
      
      return {
        success: true,
        onlineUsers: connectedUsers,
      };
    } catch (error) {
      console.error('Get online users error:', error);
      return { success: false, error: error.message };
    }
  }


  // Helper method to update connected users for a company
  private addUserToRoom(user:JwtPayload, roomId:number) {
    const roomClients = this.chatRooms.get(roomId) ;
    if (!roomClients) {
      this.chatRooms.set(roomId, [
        {
          userId: user.sub,
          username: user.username,
          companyCode: user.companyCode,
        }
      ]);
      
    }else{
      // Check if user is already in the list
      const existingUser = roomClients.find(u => u.userId === user.sub);
      if (!existingUser) {
        roomClients.push({
          userId: user.sub,
          username: user.username,
          companyCode: user.companyCode,
        });
      }
    }

  }


  // Optional: Add periodic cleanup
  onModuleInit() {
    // Run cleanup every 5 minutes
    // setInterval(() => {
    //   this.cleanupStaleConnections();
    // }, 5 * 60 * 1000);
  }
}