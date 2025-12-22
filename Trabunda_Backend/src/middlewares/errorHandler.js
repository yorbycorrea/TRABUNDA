const errorHandler = (err, req, res, next) => {
    console.error(err);

    const status = err.status || err.statusCode || 500;
    const message=
        status >= 500? "Error interno del servidor: " : err.message || "Error";

    res.status(status).json({error:message});



};

module.exports = {errorHandler};