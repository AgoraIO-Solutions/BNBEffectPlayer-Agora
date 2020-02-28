// body
// CATRigHub001
// CATRigTail1_	-> CATRigHub001
// CATRigTail2_	-> CATRigTail1_
// CATRigTail3_	-> CATRigTail2_
// CATRigTail4	-> CATRigTail3_
// CATRigTail5	-> CATRigTail4

// CATRigTail1____	-> CATRigHub001
// CATRigTail2____	-> CATRigTail1____
// CATRigTail3____	-> CATRigTail2____
// CATRigTail4___	-> CATRigTail3____
// CATRigTail5_	-> CATRigTail4___

// CATRigTail1_____	-> CATRigHub001
// CATRigTail2_____	-> CATRigTail1_____
// CATRigTail3_____	-> CATRigTail2_____
// CATRigTail4____	-> CATRigTail3_____
// CATRigTail5__	-> CATRigTail4____

// CATRigTail1__	-> CATRigHub001
// CATRigTail2__	-> CATRigTail1__
// CATRigTail3__	-> CATRigTail2__
// CATRigTail4_	-> CATRigTail3__
// CATRigTail5_____	-> CATRigTail4_

// CATRigTail1___	-> CATRigHub001
// CATRigTail2___	-> CATRigTail1___
// CATRigTail3___	-> CATRigTail2___
// CATRigTail4__	-> CATRigTail3___
// CATRigTail5______	-> CATRigTail4__

// CATRigTail1______	-> CATRigHub001
// CATRigTail2______	-> CATRigTail1______
// CATRigTail3______	-> CATRigTail2______
// CATRigTail4_____	-> CATRigTail3______
// CATRigTail5___	-> CATRigTail4_____
// CATRigTail6	-> CATRigTail5___

// CATRigTail1_______	-> CATRigHub001
// CATRigTail2_______	-> CATRigTail1_______
// CATRigTail3_______	-> CATRigTail2_______
// CATRigTail4______	-> CATRigTail3_______
// CATRigTail5____	-> CATRigTail4______
// CATRigTail6_	-> CATRigTail5____

// CATRigTail1	-> CATRigHub001
// CATRigTail2	-> CATRigTail1
// CATRigTail3	-> CATRigTail2
// CATRigTail4_______	-> CATRigTail3
// CATRigTail5_______	-> CATRigTail4_______
function Effect()
{
    var self = this;

    this.init = function() {
        Api.meshfxMsg("spawn", 5, 0, "!glfx_FACE");
        Api.meshfxMsg("spawn", 0, 0, "MonsterFactory_mesh.bsm2");
        Api.meshfxMsg("spawn", 1, 0, "MonsterFactoryMorph.bsm2");
        Api.meshfxMsg("spawn", 2, 0, "Hair.bsm2");
        Api.meshfxMsg("spawn", 3, 0, "neck_cut.bsm2");
        Api.meshfxMsg("spawn", 4, 0, "head_cut.bsm2");

        Api.meshfxMsg("dynImass", 0, 0, "body");
        Api.meshfxMsg("dynImass", 0, 0, "CATRigHub001");
        Api.meshfxMsg("dynImass", 0, 0, "CATRigTail1_______");
        Api.meshfxMsg("dynImass", 0, 0, "CATRigTail1______");
        Api.meshfxMsg("dynImass", 0, 0, "CATRigTail1_____");
        Api.meshfxMsg("dynImass", 0, 0, "CATRigTail1____");
        Api.meshfxMsg("dynImass", 0, 0, "CATRigTail1___");
        Api.meshfxMsg("dynImass", 0, 0, "CATRigTail1__");
        Api.meshfxMsg("dynImass", 0, 0, "CATRigTail1_");
        Api.meshfxMsg("dynImass", 0, 0, "CATRigTail1");

        Api.meshfxMsg("dynImass", 0, 0, "CATRigTail2_______");
        Api.meshfxMsg("dynImass", 0, 0, "CATRigTail2______");
        Api.meshfxMsg("dynImass", 0, 0, "CATRigTail2_____");
        Api.meshfxMsg("dynImass", 0, 0, "CATRigTail2____");
        Api.meshfxMsg("dynImass", 0, 0, "CATRigTail2___");
        Api.meshfxMsg("dynImass", 0, 0, "CATRigTail2__");
        Api.meshfxMsg("dynImass", 0, 0, "CATRigTail2_");
        Api.meshfxMsg("dynImass", 0, 0, "CATRigTail2");

        Api.meshfxMsg("dynImass", 0, 1, "CATRigTail3_");
        Api.meshfxMsg("dynImass", 0, 1, "CATRigTail3___");
        Api.meshfxMsg("dynImass", 0, 1, "CATRigTail3____");
        Api.meshfxMsg("dynImass", 0, 1, "CATRigTail3_____");
        Api.meshfxMsg("dynImass", 0, 1, "CATRigTail3");
        Api.meshfxMsg("dynImass", 0, 1, "CATRigTail3__");


        // Api.meshfxMsg("dynImass", 0, 0, "CATRigTail6");
        // Api.meshfxMsg("dynImass", 0, 0, "CATRigTail5___");
        // Api.meshfxMsg("dynImass", 0, 0, "CATRigTail4_____");


        Api.meshfxMsg("dynConstraint", 0, 100, "CATRigHub001 CATRigTail5____");
        Api.meshfxMsg("dynConstraint", 0, 100, "CATRigHub001 CATRigTail5___");

        Api.meshfxMsg("dynConstraint", 0, 100, "CATRigHub001 CATRigTail4______");
        Api.meshfxMsg("dynConstraint", 0, 100, "CATRigHub001 CATRigTail4_______");

        Api.meshfxMsg("dynConstraint", 0, 100, "CATRigHub001 CATRigTail3______");
        Api.meshfxMsg("dynConstraint", 0, 100, "CATRigHub001 CATRigTail3_______");

        Api.meshfxMsg("dynConstraint", 0, 100, "CATRigTail4_____ CATRigTail4______");


        Api.meshfxMsg("dynConstraint", 0, 100, "CATRigHub001 CATRigTail4_");
        Api.meshfxMsg("dynConstraint", 0, 100, "CATRigHub001 CATRigTail4___");
        Api.meshfxMsg("dynConstraint", 0, 100, "CATRigHub001 CATRigTail4____");
        Api.meshfxMsg("dynConstraint", 0, 100, "CATRigHub001 CATRigTail4_____");
        Api.meshfxMsg("dynConstraint", 0, 100, "CATRigHub001 CATRigTail4");
        Api.meshfxMsg("dynConstraint", 0, 100, "CATRigHub001 CATRigTail4__");


        Api.meshfxMsg("dynSphere", 0, 0, "-13 54 8 124");

        Api.meshfxMsg("dynDamping", 0, 95);


        Api.meshfxMsg("dynGravity", 0, 0, "0 -1700 0");

        Api.playSound("music.ogg", true, 1);
        Api.showRecordButton();
    };

    this.restart = function() {
        Api.meshfxReset();
        Api.stopSound("music.ogg");
        self.init();
    };

    this.faceActions = [];
    this.noFaceActions = [];

    this.videoRecordStartActions = [];
    this.videoRecordFinishActions = [];
    this.videoRecordDiscardActions = [this.restart];
}

configure(new Effect());