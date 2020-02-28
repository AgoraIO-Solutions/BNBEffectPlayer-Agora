var touchSprite;

var drawSize = {};
var drawScaled = {};
var viewSize = {};
var aspect;
var drawAspect;
var coef;
var gIndex = 0;

function Effect()
{
    var self = this;

    this.timeUpdate = function() {

    };

    this.coeffupdate = function() {
        if (Api.getPlatform() == "macOS") {
            drawSize.x = 720;
            drawSize.y = 1280;

            viewSize.x = 720;
            viewSize.y = 1280;
        } else {
            drawSize.x = Api.drawingAreaWidth();
            drawSize.y = Api.drawingAreaHeight();

            viewSize.x = Api.visibleAreaWidth();
            viewSize.y = Api.visibleAreaHeight();
        }
        drawAspect = drawSize.x / drawSize.y;
        viewAspect = viewSize.x / viewSize.y;
        // Api.print("Draw: " + drawSize.x + "x" + drawSize.y + "  :  " + drawAspect);
        // Api.print("View: " + viewSize.x + "x" + viewSize.y + "  :  " + viewAspect);


        if (viewAspect < drawAspect) {
            coef = viewAspect / drawAspect;
        } else if (viewAspect > drawAspect) {
            coef = drawAspect / viewAspect;
        } else {
            coef = 1;
        }
    };

    this.init = function() {
        this.coeffupdate();

        // touchSprite = new Sprite("sprite.png", 10000, 0, 1, 0.8);
        Api.showRecordButton();
    };

    this.restart = function() {
        Api.meshfxReset();
        self.init();
    };

    this.faceActions = [this.timeUpdate];
    this.noFaceActions = [this.timeUpdate];

    this.videoRecordStartActions = [];
    this.videoRecordFinishActions = [];
    this.videoRecordDiscardActions = [];
}

function Sprite(tex, x, y, opacity, scale, angle)
{
    this.index = gIndex++;
    if (gIndex > 5)
        gIndex = 0;
    this.tex = tex;
    Api.meshfxMsg("spawn", this.index, 0, "quad.bsm2");
    Api.meshfxMsg("tex", this.index, 0, this.tex);
    this.x = 0;
    this.y = 0;
    this.scale = 1;
    this.angle = 0;
    this.opacity = 1;

    this.forceX = 0;
    this.forceY = 0;
    this.forceRot = 0;

    this.transform = function(x, y, scale, angle) {
        if (x != undefined)
            this.x = x;
        if (y != undefined)
            this.y = y;
        if (scale != undefined)
            this.scale = scale;
        if (angle != undefined)
            this.angle = angle;

        this.angle_ = this.angle * Math.PI / 180;
        var pos_scale_angle = String(this.x) + " " + String(this.y) + " " + String(this.scale) + " " + String(this.angle_);
        Api.meshfxMsg("shaderVec4", 0, this.index, pos_scale_angle);
        // Api.meshfxMsg("shaderVec4", 0, this.index, "0 0 1 0");
    };

    this.scaleChange = function(scale) {
        this.scale = scale;
        this.transform();
    };

    this.angleChange = function(angle) {
        this.angle = angle;
        this.transform();
    };

    this.opacityChange = function(opacity) {
        this.opacity = opacity ? opacity : this.opacity;
        Api.meshfxMsg("shaderVec4", 0, this.index + 48, String(this.opacity));
    };

    this.onUpdate = function() {
        this.transform(
            this.x + this.forceX * deltaTime,
            this.y + this.forceY * deltaTime,
            this.scale,
            this.angle + this.forceRot * deltaTime);
    };

    this.changeForce = function(x, y) {
        this.forceX = x;
        this.forceY = y;
    };

    this.changeForceRot = function(rot) {
        this.forceRot = rot;
    };

    this.transform(x, y, scale, angle);
    this.opacityChange(opacity);

    //Api.showHint("Constructor called");
}


if (!Array.prototype.find) {
    Array.prototype.find = function(predicate) {
        if (this == null) {
            throw new TypeError('Array.prototype.find called on null or undefined');
        }
        if (typeof predicate !== 'function') {
            throw new TypeError('predicate must be a function');
        }
        var list = Object(this);
        var length = list.length >>> 0;
        var thisArg = arguments[1];
        var value;

        for (var i = 0; i < length; i++) {
            value = list[i];
            if (predicate.call(thisArg, value, i, list)) {
                return value;
            }
        }
        return undefined;
    };
}

var effect = new Effect();

configure(effect);

var activeTouches = [];

function drawWithAspect(sprite, touches, i)
{
    effect.coeffupdate();
    if (viewAspect < drawAspect) {
        sprite.transform(touches[i].x * coef, touches[i].y);
    } else if (viewAspect > drawAspect) {
        sprite.transform(touches[i].x, touches[i].y * coef);
    } else {
        sprite.transform(touches[i].x * coef, touches[i].y * coef);
    }
}

function findFunc(touchesArr, index)
{
    return function(sprite) {
        return sprite.id === touchesArr[index].id;
    };
}

function onTouchesBegan(touches)
{
    Api.print("onTouchesBegan: " + JSON.stringify(touches, null, 4));
    for (var i = 0; i < touches.length; i++) {
        var touchSprite = new Sprite("sprite.png", 10000, 0, 1, 0.8);
        touchSprite.id = touches[i].id;
        activeTouches.push(touchSprite);
        drawWithAspect(touchSprite, touches, i);
    }
}

function onTouchesMoved(touches)
{
    Api.print("onTouchesMoved: " + JSON.stringify(touches, null, 4));
    for (var i = 0; i < touches.length; i++) {
        var touchSprite = activeTouches.find(findFunc(touches, i));
        drawWithAspect(touchSprite, touches, i);
    }
}


function onTouchesEnded(touches)
{
    Api.print("onTouchesEnded: " + JSON.stringify(touches, null, 4));
    for (var i = 0; i < touches.length; i++) {
        var touchSprite = activeTouches.find(findFunc(touches, i));
        if (touchSprite) {
            var index = activeTouches.indexOf(touchSprite);
            activeTouches.splice(index, 1);
        }
    }
}
