const jwt = require("jsonwebtoken");

function authMiddleware(req, res, next){
    const header = req.headers.authorization || "";
    const token = header.startsWith("Bearer") ? header.slice(7): null;

    if(!token) return res.status(401).json({error: "Falta token (Bearrer ...)"});

    try{
        const payload =  jwt.verify(token, process.env.JWT_SECRET);
        req.user = {
            id: payload.sub,
            username: payload.username,
            roles: payload.roles || [],
            
        };
        next();


    }catch (e){
        return res.status(401).json({error: "Token invalido o expirado"});

    }

}

function requireRole(...allowed){
    return(req, res, next) => {
        const roles = req.user?.roles || [];
        const ok = allowed.some((r) => roles.includes(r));
        if(!ok) return res.status(403).json({error: "No autorizado (rol insuficiente)"});
        next();
    };
}

module.exports = {authMiddleware,requireRole};