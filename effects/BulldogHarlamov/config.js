function Effect()
{
    var self = this;

    this.init = function() {
        Api.meshfxMsg("spawn", 3, 0, "!glfx_FACE");

        Api.meshfxMsg("spawn", 0, 0, "mesh_physics.bsm2");
        /*
CATRigHub001
CATRigTail1     -> CATRigHub001
CATRigTail2     -> CATRigTail1
CATRigTail3     -> CATRigTail2
CATRigTail4     -> CATRigTail3
CATRigTail1_    -> CATRigHub001
CATRigTail2_    -> CATRigTail1_
CATRigTail3_    -> CATRigTail2_
CATRigTail4_    -> CATRigTail3_
        */

        Api.meshfxMsg("dynImass", 0, 0, "CATRigHub001");
        Api.meshfxMsg("dynImass", 0, 0, "CATRigTail1");
        Api.meshfxMsg("dynImass", 0, 0, "CATRigTail2");
        Api.meshfxMsg("dynConstraint", 0, 70, "CATRigTail3 CATRigTail1");
        Api.meshfxMsg("dynConstraint", 0, 70, "CATRigTail4 CATRigTail2");
        Api.meshfxMsg("dynConstraint", 0, 99, "CATRigTail4 ~CATRigHub001");

        Api.meshfxMsg("dynImass", 0, 0, "CATRigTail1_");
        Api.meshfxMsg("dynImass", 0, 0, "CATRigTail2_");
        Api.meshfxMsg("dynConstraint", 0, 70, "CATRigTail3_ CATRigTail1_");
        Api.meshfxMsg("dynConstraint", 0, 70, "CATRigTail4_ CATRigTail2_");
        Api.meshfxMsg("dynConstraint", 0, 99, "CATRigTail4_ ~CATRigHub001");

        //Api.meshfxMsg("dynDamping", 0, 75);
        Api.meshfxMsg("dynGravity", 0, 0, "0 -2000 0");


        Api.meshfxMsg("spawn", 1, 0, "morph.bsm2");

        Api.meshfxMsg("spawn", 2, 0, "mesh.bsm2");

        // Api.showHint("Open mouth");
        Api.playVideo("frx", true, 1);
        // Api.playSound("sfx.aac",false,1);
        Api.showRecordButton();
    };

    this.restart = function() {
        Api.meshfxReset();
        Api.stopVideo("frx");
        // Api.stopSound("sfx.aac");
        self.init();
    };

    this.faceActions = [];
    this.noFaceActions = [];

    this.videoRecordStartActions = [];
    this.videoRecordFinishActions = [];
    this.videoRecordDiscardActions = [this.restart];
}

configure(new Effect());