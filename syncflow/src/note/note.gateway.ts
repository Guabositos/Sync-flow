import {
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  OnGatewayInit,
  ConnectedSocket,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import * as jwt from 'jsonwebtoken';
import { ConfigService } from 'src/config/config.service';
import { JwtPayload } from 'src/auth/jwt-payload.interface';
import { NoteService } from './note.service';
import { NoteLineService } from './noteLine.service';
import { UpdateNoteLineDto } from './dto/update-noteLine.dto';
import { ConnectedUser } from 'src/auth/decorator/user.decorator';
import { AuthGuard } from '@nestjs/passport';
import { UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from 'src/auth/guards/jwt-auth.guard';
import { RolesGuard } from 'src/auth/role-guard';
import { WsObjectConvertPipe } from '../ws-object-convert/ws-object-convert.pipe';




/*
  to connect must include the token in auth object and the chat room id in the request URL
  Example:
  const socket = io('http://localhost:3000/whiteboard?noteId=123', {
    auth: {
      token: 'Bearer ...'
}}  });
*/
@UseGuards(JwtAuthGuard)
@WebSocketGateway({ cors: true, namespace: 'whiteboard' })
export class Notesocket implements OnGatewayConnection, OnGatewayDisconnect, OnGatewayInit {
  @WebSocketServer()
  server: Server;

  private secret: string;

  // Map<noteId, Map<userId, lineNumber>>
  private noteLocks: Map<number, Map<string, number>> = new Map();
  private noteLineCounts: Map<number, number> = new Map();


  constructor(
    private readonly noteService: NoteService,
    private readonly noteLineService: NoteLineService,
    private readonly configService: ConfigService,
  ) {
    const secret = this.configService.getJwtConfig().jwtSecret;
    if (!secret) throw new Error('JWT_SECRET is not defined');
    this.secret = secret;
  }

  async afterInit(server: Server) {
    console.log("Note Socket initialized");
    server.use((socket, next) => {
      // Verify JWT for ALL connections
      try {
        console.log("Note Socket verifying token");
        console.log("Handshake auth:", socket.handshake.auth);
        let token = socket.handshake.auth.token;
        if(!token) {
          throw new Error('No token provided');
        }
        if(token.startsWith('Bearer ')) {
          token = token.slice(7, token.length).trim();
        }
        const user = jwt.verify(token, this.secret) as unknown as JwtPayload;
        console.log("Note Socket verified user:", user);
        socket.data.user = user;
        next();
      } catch (err) {
        next(new Error('Unauthorized'));
      }
    });
  }

  async handleConnection(client: Socket) {
    try {
      console.log("Note Socket connection attempt");
      // Authenticated user is already set in socket.data by the middleware
      const user = client.data.user as JwtPayload;
      //check if user has already connected to another note and didnt disconnect properly
      for (const [noteId, userMap] of this.noteLocks) {
        if (userMap.has(user.username)) {
          const lineNumber = userMap.get(user.username);
          userMap.delete(user.username);
          if (userMap.size === 0) this.noteLocks.delete(noteId);
          this.server.to(user.companyCode + noteId.toString()).emit('softunlock', {
            userId: user.sub,
            noteId,
            lineNumber,
          });
          console.log(`Disconnected previous session for user ${user.username} – lock removed`);
        }
      }

      //check if user is allowed to access the note
      const noteId = parseInt(client.handshake.query.noteId as string);
      if(isNaN(noteId) || !noteId) {
        client.disconnect();
        throw new Error('Invalid noteId');
      }
      client.data.noteId = noteId;
      if ((await this.noteService.checkifUserInNote(user, noteId)) === false) {
        client.disconnect();
        return;
      }

      //add user to the room and, if no one is in the room, get the line count for the note
      client.join(user.companyCode + noteId.toString());
      if (!(this.noteLineCounts.has(noteId))) {
        const lineCount = await this.noteService.lineCount(noteId);
        this.noteLineCounts.set(noteId, lineCount);
      }
      console.log(`Connected: ${user.username} [${user.sub}]`);


      // Send all current locks that concern the user
      const allLocks: { username: string; lineNumber: number }[] = [];
      this.noteLocks.forEach((userMap, $noteId) => {
        if (noteId === $noteId) {
          userMap.forEach((lineNumber, username) => {
            allLocks.push({ username, lineNumber });
          });
        }
      });
      console.log('Sending current softlocks:', allLocks);

      setTimeout(() => {
        this.server.to(client.id).emit('currentSoftlocks', allLocks);
      }, 100);


    } catch (err) {


      console.error('Socket auth failed:', err.message);
      client.disconnect();
    }
  }


  async handleDisconnect(client: Socket) {
    // get the user data that is already registered with the socket
    const user: JwtPayload = client.data.user;
    const noteId = client.data.noteId;
    if (!user) return;

    //remove his locks if they exist and remove the note line numbers if he is last in the room
    const noteLocksForNote = this.noteLocks.get(noteId);
    if (noteLocksForNote?.has(user.username)) {
      const lineNumber = noteLocksForNote?.get(user.username);
      noteLocksForNote?.delete(user.username);
      if (noteLocksForNote?.size === 0) this.noteLocks.delete(noteId);
      this.server.to(user.companyCode + noteId.toString()).emit('softunlock', {
        userId: user.sub,
        noteId,
        lineNumber,
      });
    }
    console.log(`Disconnected: ${user.username} – lock removed`);
  }


  @SubscribeMessage('softlock')
  async handleSoftLock(
    @MessageBody(WsObjectConvertPipe) data: { lineNumber: number },
    @ConnectedUser() user: JwtPayload,
    @ConnectedSocket() client: Socket,
  ) {
    const noteId = client.data.noteId;
    
    console.log(`Received softlock request from ${user.username} for note ${noteId} at line ${data.lineNumber}`);
    let lineCount = this.noteLineCounts.get(noteId);
    if (lineCount === undefined) {
      lineCount = await this.noteService.lineCount(noteId);
      this.noteLineCounts.set(noteId, lineCount);
    }

    // Extend the note if within last 5 lines
    if (data.lineNumber >= lineCount - 5) {
      const newLines = await this.noteLineService.createMultiple(5, noteId);
      this.noteLineCounts.set(noteId, lineCount + 5);
      console.log(`Created 5 new lines for note ${noteId}:`, newLines);

      // Notify all clients in the company about the new page
      this.server.to(user.companyCode + noteId.toString()).emit('newPageCreated', {
        noteId: noteId,
        newLines,
      });

      console.log(`Extended note ${noteId} with 5 new lines.`);
    }

    // Check if the user already has a lock
    for (const [$noteId, userMap] of this.noteLocks) {
      if (userMap.has(user.username)) {
        const oldLineNumber = userMap.get(user.username);

        // If it's the same noteId and lineNumber, skip
        if (noteId === $noteId && oldLineNumber === data.lineNumber) {
          return;
        }

        // Remove old lock
        userMap.delete(user.username);
        if (userMap.size === 0) this.noteLocks.delete($noteId);

        this.server.to(user.companyCode + noteId.toString()).emit('softunlock', {
          userId: user.sub,
          noteId,
          lineNumber: oldLineNumber,
        });

        break; // Only one lock per user globally
      }
    }

    // Set new lock
    if (!this.noteLocks.has(noteId)) {
      this.noteLocks.set(noteId, new Map());
    }
    const userMap = this.noteLocks.get(noteId);
    if (userMap) {
      userMap.set(user.username, data.lineNumber);
    }

    this.server.to(user.companyCode + noteId.toString()).emit('softlock', {
      username: user.username,
      noteId: noteId,
      lineNumber: data.lineNumber,
    });
  }


  @SubscribeMessage('softunlock')
  async handleSoftUnlock(
    @MessageBody(WsObjectConvertPipe) data: { lineNumber: number },
    @ConnectedUser() user: JwtPayload,
    @ConnectedSocket() client: Socket,
  ) {
    const noteId = client.data.noteId;
    console.log(`Received softunlock request from ${user.username} for note ${noteId} at line ${data.lineNumber}`);

    const userMap = this.noteLocks.get(noteId);
    if (userMap && userMap.get(user.username) === data.lineNumber) {
      userMap.delete(user.username);
      if (userMap.size === 0) this.noteLocks.delete(noteId);

      this.server.to(user.companyCode + noteId.toString()).emit('softunlock', {
        username: user.username,
        noteId: noteId,
        lineNumber: data.lineNumber,
      });
    }
  }


  @SubscribeMessage('alterNote')
  async handleNoteAltered(
    @MessageBody(WsObjectConvertPipe) note: UpdateNoteLineDto,
    @ConnectedUser() user: JwtPayload,
    @ConnectedSocket() client: Socket,
  ) {
    const noteId = client.data.noteId;
    console.log('Received note alteration request:', note);

    // Check if the user has a soft lock on this noteId and lineNumber
    const userMap = this.noteLocks.get(noteId);
    const lockedLineNumber = userMap?.get(user.username);

    if (lockedLineNumber !== note.lineNumber) {
      // User does not hold lock on this line - reject the update
      console.warn(
        `User ${user.username} attempted to alter line ${note.lineNumber} of note ${note.noteId} without holding the soft lock.`
      );
      // Optionally emit an error to client:
      this.server.to(user.companyCode + noteId.toString()).emit('error', {
        message: 'You must hold the soft lock on this line to alter it.',
        noteId: note.noteId,
        lineNumber: note.lineNumber,
      });
      return;
    }

    try {
      // User holds the lock, allow partial update
      console.log('Updating note line:', note);
      const updatedNoteLine = await this.noteLineService.update(
        noteId,
        note,
        user.sub,
      );
      if (updatedNoteLine == null) {
        return;
      }
      console.log('Note line updated successfully:', updatedNoteLine);
      this.server.to(user.companyCode + noteId.toString()).emit('noteUpdated', updatedNoteLine);
    } catch (error) {
      console.error('Error updating note line:', error);
      // Optionally emit an error event to the client here
    }
  }



}
