import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import { checkFirestoreConnection } from '../database/firebase.js';
import { usersRouter } from '../modules/users/users.routes.js';
import { presenceRouter } from '../modules/presence/presence.routes.js';
import { typingRouter } from '../modules/typing/typing.routes.js';
import { chatRouter } from '../modules/chat/chat.routes.js';
import { activitiesRouter } from '../modules/activities/activities.routes.js';


export function createApp(){
    const app = express();

    app.use(cors());
    app.use(helmet());
    app.use(morgan('dev'));
    app.use(express.json());

    app.get("/health", async (_req, res) =>{
        try {
            await checkFirestoreConnection();
            res.json({
                ok: true,
                data:{
                    status : 'ok',
                    service: 'api-server',
                    database: 'connected',
                },
            })
        } catch (error) {
            res.status(503).json({
                ok: false,
                error: {
                    code: 'DB_UNAVAILABLE',
                    message: 'Firestore unreachable',
                },
            })
        }
    })

    app.use("/users", usersRouter);
    app.use("/presence", presenceRouter);
    app.use('/typing', typingRouter);
    app.use('/chat', chatRouter);
    app.use('/activities', activitiesRouter);

    return app;
}